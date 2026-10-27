from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.security import hash_password, require_admin, verify_password
from app.db.session import get_db
from app.models import PartnerProfile, StaffPartnerAssignment, StaffProfile, User
from app.schemas.admin_users import (
    AccountStatusUpdateRequest,
    AssignmentUserResponse,
    AdminUserDetailResponse,
    AdminUserSummary,
    PaginatedUsersResponse,
    PaginationMetadata,
    PartnerCreateRequest,
    StaffCreateRequest,
    StaffPartnerAssignmentCreateRequest,
    StaffPartnerAssignmentResponse,
)
from app.schemas.auth import (
    AdminPasswordUpdateRequest,
    AdminPasswordUpdateResponse,
    AdminUserResponse,
)

router = APIRouter(prefix="/api/v1/admin", tags=["admin"])


def _assignment_response(
    assignment: StaffPartnerAssignment,
) -> StaffPartnerAssignmentResponse:
    staff_user = assignment.staff.user
    partner_user = assignment.partner.user
    return StaffPartnerAssignmentResponse(
        id=assignment.id,
        staff_id=assignment.staff_id,
        partner_id=assignment.partner_id,
        assigned_at=assignment.assigned_at,
        is_active=assignment.is_active,
        staff=AssignmentUserResponse(
            id=staff_user.id,
            name=staff_user.name,
            mobile=staff_user.mobile,
            role=staff_user.role,
            is_active=staff_user.is_active,
            staff_id=assignment.staff.staff_id,
        ),
        partner=AssignmentUserResponse(
            id=partner_user.id,
            name=partner_user.name,
            mobile=partner_user.mobile,
            role=partner_user.role,
            is_active=partner_user.is_active,
            business_name=assignment.partner.business_name,
            partner_code=assignment.partner.partner_code,
        ),
    )


def _load_assignment(db: Session, assignment_id: int) -> StaffPartnerAssignment:
    return db.scalar(
        select(StaffPartnerAssignment)
        .options(
            selectinload(StaffPartnerAssignment.staff).selectinload(
                StaffProfile.user
            ),
            selectinload(StaffPartnerAssignment.partner).selectinload(
                PartnerProfile.user
            ),
        )
        .where(StaffPartnerAssignment.id == assignment_id)
    )


@router.get("/me", response_model=AdminUserResponse)
def get_current_admin(
    current_admin: User = Depends(require_admin),
) -> AdminUserResponse:
    return AdminUserResponse.model_validate(current_admin)


@router.post("/me/password", response_model=AdminPasswordUpdateResponse)
def update_current_admin_password(
    payload: AdminPasswordUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminPasswordUpdateResponse:
    """
    Securely update the authenticated Admin's password.
    Requires current password verification and enforces password policies.
    """
    # Verify current password against stored bcrypt hash
    if not verify_password(payload.current_password, current_admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )

    # Disallow reusing the current password
    if payload.current_password == payload.new_password:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from current password",
        )

    # Hash new password using bcrypt
    current_admin.password_hash = hash_password(payload.new_password)
    db.commit()

    return AdminPasswordUpdateResponse(message="Password updated successfully")


@router.get(
    "/users",
    response_model=PaginatedUsersResponse,
)
def list_users(
    role: Literal["customer", "partner", "staff", "admin"] | None = Query(default=None),
    search: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PaginatedUsersResponse:
    """
    List users with database-side filtering, deterministic pagination, and
    eager-loaded profile relations to prevent N+1 queries.
    """
    filters = []
    if role is not None:
        filters.append(User.role == role)
    if is_active is not None:
        filters.append(User.is_active == is_active)
    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            filters.append(
                User.name.ilike(pattern) | User.mobile.ilike(pattern)
            )

    total = db.scalar(select(func.count()).select_from(User).where(*filters)) or 0
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    offset = (page - 1) * page_size

    users = db.scalars(
        select(User)
        .options(
            selectinload(User.partner_profile),
            selectinload(User.staff_profile),
            selectinload(User.customer_profile),
        )
        .where(*filters)
        .order_by(User.created_at.desc(), User.id.desc())
        .offset(offset)
        .limit(page_size)
    ).all()

    items = [AdminUserSummary.model_validate(u) for u in users]
    meta = PaginationMetadata(
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
    )
    return PaginatedUsersResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        pagination=meta,
    )


@router.get(
    "/staff-partner-assignments",
    response_model=list[StaffPartnerAssignmentResponse],
)
def list_staff_partner_assignments(
    is_active: bool | None = Query(default=None),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> list[StaffPartnerAssignmentResponse]:
    query = (
        select(StaffPartnerAssignment)
        .options(
            selectinload(StaffPartnerAssignment.staff).selectinload(
                StaffProfile.user
            ),
            selectinload(StaffPartnerAssignment.partner).selectinload(
                PartnerProfile.user
            ),
        )
        .order_by(StaffPartnerAssignment.assigned_at.desc(), StaffPartnerAssignment.id.desc())
    )
    if is_active is not None:
        query = query.where(StaffPartnerAssignment.is_active.is_(is_active))
    assignments = db.scalars(query).all()
    return [_assignment_response(assignment) for assignment in assignments]


@router.post(
    "/staff-partner-assignments",
    response_model=StaffPartnerAssignmentResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_staff_partner_assignment(
    payload: StaffPartnerAssignmentCreateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> StaffPartnerAssignmentResponse:
    staff_profile = db.scalar(
        select(StaffProfile)
        .options(selectinload(StaffProfile.user))
        .where(StaffProfile.user_id == payload.staff_id)
    )
    if staff_profile is None:
        staff_user = db.get(User, payload.staff_id)
        if staff_user is None:
            raise HTTPException(status_code=404, detail="Staff member not found")
        if staff_user.role != "staff":
            raise HTTPException(
                status_code=422,
                detail="Selected user does not have a Staff profile",
            )
        raise HTTPException(
            status_code=422,
            detail="Selected Staff account is missing its Staff profile",
        )
    if staff_profile.user.role != "staff":
        raise HTTPException(
            status_code=422,
            detail="Selected user does not have the Staff role",
        )
    if not staff_profile.user.is_active:
        raise HTTPException(
            status_code=422,
            detail="Selected Staff account is inactive",
        )

    partner_profile = db.scalar(
        select(PartnerProfile)
        .options(selectinload(PartnerProfile.user))
        .where(PartnerProfile.user_id == payload.partner_id)
    )
    if partner_profile is None:
        partner_user = db.get(User, payload.partner_id)
        if partner_user is None:
            raise HTTPException(status_code=404, detail="Partner not found")
        if partner_user.role != "partner":
            raise HTTPException(
                status_code=422,
                detail="Selected user does not have a Partner profile",
            )
        raise HTTPException(
            status_code=422,
            detail="Selected Partner account is missing its Partner profile",
        )
    if partner_profile.user.role != "partner":
        raise HTTPException(
            status_code=422,
            detail="Selected user does not have the Partner role",
        )
    if not partner_profile.user.is_active:
        raise HTTPException(
            status_code=422,
            detail="Selected Partner account is inactive",
        )

    existing = db.scalar(
        select(StaffPartnerAssignment.id).where(
            StaffPartnerAssignment.staff_id == payload.staff_id,
            StaffPartnerAssignment.partner_id == payload.partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="This Partner is already assigned to this Staff member",
        )

    assignment = StaffPartnerAssignment(
        staff=staff_profile,
        partner=partner_profile,
        is_active=True,
    )
    db.add(assignment)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        constraint_name = getattr(
            getattr(exc.orig, "diag", None),
            "constraint_name",
            None,
        )
        if constraint_name == "uq_staff_partner_assignments_active_pair":
            raise HTTPException(
                status_code=409,
                detail="This Partner is already assigned to this Staff member",
            ) from exc
        raise

    fresh_assignment = _load_assignment(db, assignment.id)
    return _assignment_response(fresh_assignment)


@router.get(
    "/users/{user_id}",
    response_model=AdminUserDetailResponse,
)
def get_user_detail(
    user_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDetailResponse:
    """
    Retrieve full user details including role-specific profile data.
    Never exposes passwords, hashes, or credentials.
    """
    user = db.scalar(
        select(User)
        .options(
            selectinload(User.customer_profile),
            selectinload(User.partner_profile),
            selectinload(User.staff_profile),
        )
        .where(User.id == user_id)
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return AdminUserDetailResponse.model_validate(user)


@router.post(
    "/users/partners",
    response_model=AdminUserDetailResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_partner_user(
    payload: PartnerCreateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDetailResponse:
    """
    Create a partner user and associated PartnerProfile in a single transaction.
    Rejects duplicate mobile numbers and non-empty partner codes with HTTP 409.
    """
    if db.scalar(select(User.id).where(User.mobile == payload.mobile)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this mobile number already exists",
        )

    if payload.partner_code:
        if db.scalar(
            select(PartnerProfile.user_id).where(
                PartnerProfile.partner_code == payload.partner_code
            )
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A partner with this partner code already exists",
            )

    try:
        user = User(
            name=payload.name,
            mobile=payload.mobile,
            password_hash=hash_password(payload.password),
            role="partner",
            is_active=True,
        )
        db.add(user)
        db.flush()

        profile = PartnerProfile(
            user_id=user.id,
            business_name=payload.business_name,
            business_address=payload.business_address,
            partner_code=payload.partner_code,
        )
        db.add(profile)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        err_str = str(exc.orig).lower() if exc.orig else str(exc).lower()
        if "mobile" in err_str:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A user with this mobile number already exists",
            )
        if "partner_code" in err_str:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A partner with this partner code already exists",
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A duplicate record violates unique database constraints",
        )
    except Exception:
        db.rollback()
        raise

    fresh_user = db.scalar(
        select(User)
        .options(
            selectinload(User.partner_profile),
            selectinload(User.staff_profile),
            selectinload(User.customer_profile),
        )
        .where(User.id == user.id)
    )
    return AdminUserDetailResponse.model_validate(fresh_user)


@router.post(
    "/users/staff",
    response_model=AdminUserDetailResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_staff_user(
    payload: StaffCreateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDetailResponse:
    """
    Create a staff user and associated StaffProfile in a single transaction.
    Rejects duplicate mobile numbers and staff IDs with HTTP 409.
    """
    if db.scalar(select(User.id).where(User.mobile == payload.mobile)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this mobile number already exists",
        )

    if db.scalar(
        select(StaffProfile.user_id).where(StaffProfile.staff_id == payload.staff_id)
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A staff member with this staff ID already exists",
        )

    try:
        user = User(
            name=payload.name,
            mobile=payload.mobile,
            password_hash=hash_password(payload.password),
            role="staff",
            is_active=True,
        )
        db.add(user)
        db.flush()

        profile = StaffProfile(
            user_id=user.id,
            staff_id=payload.staff_id,
        )
        db.add(profile)
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        err_str = str(exc.orig).lower() if exc.orig else str(exc).lower()
        if "mobile" in err_str:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A user with this mobile number already exists",
            )
        if "staff_id" in err_str:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A staff member with this staff ID already exists",
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A duplicate record violates unique database constraints",
        )
    except Exception:
        db.rollback()
        raise

    fresh_user = db.scalar(
        select(User)
        .options(
            selectinload(User.partner_profile),
            selectinload(User.staff_profile),
            selectinload(User.customer_profile),
        )
        .where(User.id == user.id)
    )
    return AdminUserDetailResponse.model_validate(fresh_user)


@router.post(
    "/users/{user_id}/status",
    response_model=AdminUserSummary,
)
def update_user_status(
    user_id: int,
    payload: AccountStatusUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserSummary:
    """
    Activate or deactivate a user account.
    Safeguards:
    - Target user must exist (404).
    - Prevents self-deactivation (400).
    - Prevents deactivating the last active Admin (400).
    - Transaction-safe with database-specific row-locking considerations.
    - Never deletes users or alters roles.
    """
    target_user = db.scalar(
        select(User)
        .options(
            selectinload(User.partner_profile),
            selectinload(User.staff_profile),
            selectinload(User.customer_profile),
        )
        .where(User.id == user_id)
    )
    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # Reject self-deactivation
    if target_user.id == current_admin.id and not payload.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot deactivate your own admin account",
        )

    # Protect against deactivation of the last active Admin
    if target_user.role == "admin" and not payload.is_active and target_user.is_active:
        # Documented locking mechanism:
        # In PostgreSQL, we lock active admin rows with FOR UPDATE to prevent race conditions
        # when concurrent admins attempt to deactivate one another.
        # SQLite does not support row-level SELECT ... FOR UPDATE; however, SQLite serializes
        # all write transactions at the database connection level.
        is_postgres = bool(db.bind and db.bind.dialect.name == "postgresql")
        if is_postgres:
            active_admin_ids = db.scalars(
                select(User.id)
                .where(User.role == "admin", User.is_active.is_(True))
                .with_for_update()
            ).all()
            active_admin_count = len(active_admin_ids)
        else:
            active_admin_count = db.scalar(
                select(func.count())
                .select_from(User)
                .where(User.role == "admin", User.is_active.is_(True))
            ) or 0

        if active_admin_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot deactivate the last active admin account",
            )

    try:
        target_user.is_active = payload.is_active
        db.commit()
        db.refresh(target_user)
    except Exception:
        db.rollback()
        raise

    return AdminUserSummary.model_validate(target_user)
