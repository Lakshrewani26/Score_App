from __future__ import annotations

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.security import hash_password, require_admin, verify_password
from app.db.session import get_db
from app.models import (
    CustomerProfile,
    Order,
    OrderStatusHistory,
    PartnerProfile,
    PaymentStatusHistory,
    PointsRule,
    QrBatch,
    QrCode,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    StockRequest,
    StockRequestStatusHistory,
    User,
    Zone,
)
from app.schemas.admin_users import (
    AccountStatusUpdateRequest,
    AdminUserDeleteResponse,
    AdminUserDetailResponse,
    AdminUserSummary,
    AdminUserUpdateRequest,
    AssignmentUserResponse,
    CustomerCreateRequest,
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
    zone_id: int | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PaginatedUsersResponse:
    """
    List users with database-side filtering, deterministic pagination, and
    eager-loaded profile relations to prevent N+1 queries.
    Supports filtering by role, is_active, zone_id, and searching by name, mobile, id, or code.
    """
    filters = []
    if role is not None:
        filters.append(User.role == role)
    if is_active is not None:
        filters.append(User.is_active == is_active)
    if zone_id is not None:
        filters.append(User.partner_profile.has(PartnerProfile.zone_id == zone_id))
    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            search_cond = (
                User.name.ilike(pattern)
                | User.mobile.ilike(pattern)
                | User.partner_profile.has(PartnerProfile.partner_code.ilike(pattern))
                | User.staff_profile.has(StaffProfile.staff_id.ilike(pattern))
            )
            if clean_search.isdigit():
                search_cond = search_cond | (User.id == int(clean_search))
            filters.append(search_cond)

    total = db.scalar(select(func.count()).select_from(User).where(*filters)) or 0
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    offset = (page - 1) * page_size

    users = db.scalars(
        select(User)
        .options(
            selectinload(User.partner_profile).selectinload(PartnerProfile.zone),
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
            selectinload(User.partner_profile).selectinload(PartnerProfile.zone),
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
    "/users/customers",
    response_model=AdminUserDetailResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_customer_user(
    payload: CustomerCreateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDetailResponse:
    """
    Create a customer user and associated CustomerProfile in a single transaction.
    Rejects duplicate mobile numbers with HTTP 409 Conflict.
    """
    if db.scalar(select(User.id).where(User.mobile == payload.mobile)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this mobile number already exists",
        )

    try:
        user = User(
            name=payload.name,
            mobile=payload.mobile,
            password_hash=hash_password(payload.password),
            role="customer",
            is_active=True,
        )
        db.add(user)
        db.flush()

        profile = CustomerProfile(
            user_id=user.id,
            state=payload.state,
            city=payload.city,
            segment=payload.segment,
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
            selectinload(User.customer_profile),
            selectinload(User.partner_profile).selectinload(PartnerProfile.zone),
            selectinload(User.staff_profile),
        )
        .where(User.id == user.id)
    )
    return AdminUserDetailResponse.model_validate(fresh_user)


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
    Assigns optional Zone if provided.
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

    if payload.zone_id:
        zone = db.get(Zone, payload.zone_id)
        if zone is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Zone with ID {payload.zone_id} not found",
            )
        if not zone.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot assign an inactive Zone",
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
            zone_id=payload.zone_id,
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
            selectinload(User.partner_profile).selectinload(PartnerProfile.zone),
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


@router.put("/users/{user_id}", response_model=AdminUserDetailResponse)
@router.patch("/users/{user_id}", response_model=AdminUserDetailResponse)
@router.post("/users/{user_id}/update", response_model=AdminUserDetailResponse)
def update_user(
    user_id: int,
    payload: AdminUserUpdateRequest,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDetailResponse:
    """
    Update user account details for Customer, Partner, or Staff accounts.
    Enforces uniqueness constraints on mobile, partner_code, and staff_id.
    """
    target_user = db.scalar(
        select(User)
        .options(
            selectinload(User.customer_profile),
            selectinload(User.partner_profile).selectinload(PartnerProfile.zone),
            selectinload(User.staff_profile),
        )
        .where(User.id == user_id)
    )
    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    updates = payload.model_dump(exclude_unset=True)

    # 1. Update basic fields on User
    if "name" in updates and updates["name"]:
        target_user.name = updates["name"].strip()

    if "mobile" in updates and updates["mobile"]:
        clean_mobile = updates["mobile"].strip()
        if clean_mobile != target_user.mobile:
            existing_mobile = db.scalar(
                select(User.id).where(User.mobile == clean_mobile, User.id != user_id)
            )
            if existing_mobile:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="A user with this mobile number already exists",
                )
            target_user.mobile = clean_mobile

    # 2. Update role-specific fields
    if target_user.role == "customer":
        if not target_user.customer_profile:
            target_user.customer_profile = CustomerProfile(user_id=target_user.id)
            db.add(target_user.customer_profile)
        if "state" in updates:
            target_user.customer_profile.state = updates["state"]
        if "city" in updates:
            target_user.customer_profile.city = updates["city"]
        if "segment" in updates:
            target_user.customer_profile.segment = updates["segment"]

    elif target_user.role == "partner":
        if not target_user.partner_profile:
            target_user.partner_profile = PartnerProfile(
                user_id=target_user.id,
                business_name=target_user.name,
                business_address="N/A",
            )
            db.add(target_user.partner_profile)
        if "business_name" in updates and updates["business_name"]:
            target_user.partner_profile.business_name = updates["business_name"].strip()
        if "business_address" in updates and updates["business_address"]:
            target_user.partner_profile.business_address = updates["business_address"].strip()
        if "partner_code" in updates:
            clean_code = updates["partner_code"].strip() if updates["partner_code"] else None
            if clean_code and clean_code != target_user.partner_profile.partner_code:
                existing_code = db.scalar(
                    select(PartnerProfile.user_id).where(
                        PartnerProfile.partner_code == clean_code,
                        PartnerProfile.user_id != user_id,
                    )
                )
                if existing_code:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="A partner with this partner code already exists",
                    )
            target_user.partner_profile.partner_code = clean_code

        # Zone assignment update
        if updates.get("clear_zone"):
            target_user.partner_profile.zone_id = None
        elif "zone_id" in updates and updates["zone_id"] is not None:
            zone = db.get(Zone, updates["zone_id"])
            if zone is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Assigned Zone not found",
                )
            if not zone.is_active:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cannot assign an inactive Zone",
                )
            target_user.partner_profile.zone_id = updates["zone_id"]

    elif target_user.role == "staff":
        if not target_user.staff_profile:
            target_user.staff_profile = StaffProfile(
                user_id=target_user.id,
                staff_id=f"EMP{target_user.id}",
            )
            db.add(target_user.staff_profile)
        if "staff_id" in updates and updates["staff_id"]:
            clean_sid = updates["staff_id"].strip()
            if clean_sid != target_user.staff_profile.staff_id:
                existing_sid = db.scalar(
                    select(StaffProfile.user_id).where(
                        StaffProfile.staff_id == clean_sid,
                        StaffProfile.user_id != user_id,
                    )
                )
                if existing_sid:
                    raise HTTPException(
                        status_code=status.HTTP_409_CONFLICT,
                        detail="A staff member with this staff ID already exists",
                    )
                target_user.staff_profile.staff_id = clean_sid

    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Update violates unique database constraints",
        ) from exc
    except Exception:
        db.rollback()
        raise

    fresh_user = db.scalar(
        select(User)
        .options(
            selectinload(User.customer_profile),
            selectinload(User.partner_profile).selectinload(PartnerProfile.zone),
            selectinload(User.staff_profile),
        )
        .where(User.id == target_user.id)
    )
    return AdminUserDetailResponse.model_validate(fresh_user)


@router.delete("/users/{user_id}", response_model=AdminUserDeleteResponse)
def delete_user(
    user_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> AdminUserDeleteResponse:
    """
    Delete or safely deactivate a user account subject to data retention rules.
    If the account has historical transactions (orders, payments, assignments, qr codes),
    soft-deactivates the user to preserve historical integrity and referential constraints.
    If no historical references exist, permanently deletes the account.
    """
    target_user = db.get(User, user_id)
    if target_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if target_user.id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete your own admin account",
        )

    if target_user.role == "admin" and target_user.is_active:
        active_admin_count = db.scalar(
            select(func.count()).select_from(User).where(User.role == "admin", User.is_active.is_(True))
        ) or 0
        if active_admin_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot delete the last active admin account",
            )

    # Check for historical references across models
    has_orders = db.scalar(
        select(Order.id).where((Order.partner_id == user_id) | (Order.approved_by == user_id)).limit(1)
    ) is not None
    has_order_history = db.scalar(
        select(OrderStatusHistory.id).where(OrderStatusHistory.changed_by == user_id).limit(1)
    ) is not None
    has_stock_requests = db.scalar(
        select(StockRequest.id).where((StockRequest.partner_id == user_id) | (StockRequest.reviewed_by == user_id)).limit(1)
    ) is not None
    has_stock_history = db.scalar(
        select(StockRequestStatusHistory.id).where(StockRequestStatusHistory.changed_by == user_id).limit(1)
    ) is not None
    has_assignments = db.scalar(
        select(StaffPartnerAssignment.id).where(
            (StaffPartnerAssignment.staff_id == user_id) | (StaffPartnerAssignment.partner_id == user_id)
        ).limit(1)
    ) is not None
    has_payments = db.scalar(
        select(StaffPaymentRecord.id).where(
            (StaffPaymentRecord.staff_id == user_id)
            | (StaffPaymentRecord.partner_id == user_id)
            | (StaffPaymentRecord.recorded_by == user_id)
        ).limit(1)
    ) is not None
    has_payment_history = db.scalar(
        select(PaymentStatusHistory.id).where(PaymentStatusHistory.changed_by == user_id).limit(1)
    ) is not None
    has_qr_batches = db.scalar(
        select(QrBatch.id).where((QrBatch.target_user_id == user_id) | (QrBatch.created_by == user_id)).limit(1)
    ) is not None
    has_qr_codes = db.scalar(
        select(QrCode.id).where((QrCode.target_user_id == user_id) | (QrCode.redeemed_by == user_id)).limit(1)
    ) is not None

    has_history = any([
        has_orders,
        has_order_history,
        has_stock_requests,
        has_stock_history,
        has_assignments,
        has_payments,
        has_payment_history,
        has_qr_batches,
        has_qr_codes,
    ])

    if has_history:
        target_user.is_active = False
        db.commit()
        return AdminUserDeleteResponse(
            message="Account has associated transaction history and has been deactivated to preserve records.",
            user_id=user_id,
            action="deactivated",
        )
    else:
        if target_user.customer_profile:
            db.delete(target_user.customer_profile)
        if target_user.partner_profile:
            db.delete(target_user.partner_profile)
        if target_user.staff_profile:
            db.delete(target_user.staff_profile)
        db.delete(target_user)
        db.commit()
        return AdminUserDeleteResponse(
            message="Account deleted successfully.",
            user_id=user_id,
            action="deleted",
        )

