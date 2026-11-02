from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.core.security import (
    create_access_token,
    hash_password,
    require_customer,
    require_partner,
    verify_password,
)
from app.db.session import get_db
from app.models import CustomerProfile, StaffProfile, User
from app.schemas.auth import (
    AdminLoginRequest,
    AdminUserResponse,
    CustomerLoginRequest,
    CustomerRegisterRequest,
    CustomerTokenResponse,
    CustomerUserResponse,
    PartnerLoginRequest,
    PartnerTokenResponse,
    PartnerUserResponse,
    StaffLoginRequest,
    StaffTokenResponse,
    StaffUserResponse,
    TokenResponse,
)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])

# Standard bcrypt hash for timing-safe comparison on nonexistent users
_TIMING_SAFE_DUMMY_HASH = "$2b$12$e868d44747792ecf69d3eO1l69V4v13nBvR6c.g6U8l5K4D.nL5ea"


@router.post("/admin/login", response_model=TokenResponse)
def admin_login(
    payload: AdminLoginRequest,
    db: Session = Depends(get_db),
) -> TokenResponse:
    cleaned_mobile = payload.mobile.strip()
    user = db.scalars(select(User).where(User.mobile == cleaned_mobile)).first()

    if user is None:
        # Perform dummy verification to prevent timing-based user enumeration
        verify_password(payload.password, _TIMING_SAFE_DUMMY_HASH)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Admin privileges required",
        )

    expires_delta = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
        expires_delta=expires_delta,
    )

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=int(expires_delta.total_seconds()),
        user=AdminUserResponse.model_validate(user),
    )


@router.post("/partner/login", response_model=PartnerTokenResponse)
def partner_login(
    payload: PartnerLoginRequest,
    db: Session = Depends(get_db),
) -> PartnerTokenResponse:
    cleaned_mobile = payload.mobile.strip()
    user = db.scalars(
        select(User)
        .options(selectinload(User.partner_profile))
        .where(User.mobile == cleaned_mobile)
    ).first()

    if user is None:
        verify_password(payload.password, _TIMING_SAFE_DUMMY_HASH)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    if user.role != "partner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Partner privileges required",
        )

    expires_delta = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
        expires_delta=expires_delta,
    )

    return PartnerTokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=int(expires_delta.total_seconds()),
        user=PartnerUserResponse.model_validate(user),
    )


@router.post("/staff/login", response_model=StaffTokenResponse)
def staff_login(
    payload: StaffLoginRequest,
    db: Session = Depends(get_db),
) -> StaffTokenResponse:
    cleaned_staff_id = payload.staff_id.strip()
    staff_profile = db.scalars(
        select(StaffProfile)
        .options(selectinload(StaffProfile.user))
        .where(StaffProfile.staff_id == cleaned_staff_id)
    ).first()
    user = staff_profile.user if staff_profile is not None else None

    if user is None:
        verify_password(payload.password, _TIMING_SAFE_DUMMY_HASH)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Staff ID or password",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Staff ID or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    if user.role != "staff":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Staff privileges required",
        )

    expires_delta = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
        expires_delta=expires_delta,
    )
    return StaffTokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=int(expires_delta.total_seconds()),
        user=StaffUserResponse(
            id=user.id,
            name=user.name,
            mobile=user.mobile,
            role=user.role,
            is_active=user.is_active,
            staff_id=staff_profile.staff_id,
            created_at=user.created_at,
        ),
    )


@router.get("/partner/me", response_model=PartnerUserResponse)
def partner_me(
    current_partner: User = Depends(require_partner),
    db: Session = Depends(get_db),
) -> PartnerUserResponse:
    # Ensure partner_profile is eagerly loaded
    user = db.scalars(
        select(User)
        .options(selectinload(User.partner_profile))
        .where(User.id == current_partner.id)
    ).first()
    if user is None:
        raise HTTPException(status_code=404, detail="Partner account not found")
    return PartnerUserResponse.model_validate(user)


@router.post(
    "/customer/register",
    response_model=CustomerTokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def customer_register(
    payload: CustomerRegisterRequest,
    db: Session = Depends(get_db),
) -> CustomerTokenResponse:
    cleaned_mobile = payload.mobile.strip()
    cleaned_name = payload.name.strip()

    if not cleaned_name:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Name cannot be empty",
        )
    if not cleaned_mobile:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Mobile number cannot be empty",
        )

    if db.scalar(select(User.id).where(User.mobile == cleaned_mobile)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A user with this mobile number already exists",
        )

    try:
        user = User(
            name=cleaned_name,
            mobile=cleaned_mobile,
            password_hash=hash_password(payload.password),
            role="customer",
            is_active=True,
        )
        db.add(user)
        db.flush()

        profile = CustomerProfile(
            user_id=user.id,
            state=payload.state.strip() if payload.state else None,
            city=payload.city.strip() if payload.city else None,
            segment=payload.segment.strip() if payload.segment else None,
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

    fresh_user = db.scalars(
        select(User)
        .options(selectinload(User.customer_profile))
        .where(User.id == user.id)
    ).first()

    expires_delta = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    token = create_access_token(
        subject=str(fresh_user.id),
        role=fresh_user.role,
        mobile=fresh_user.mobile,
        expires_delta=expires_delta,
    )

    return CustomerTokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=int(expires_delta.total_seconds()),
        user=CustomerUserResponse.model_validate(fresh_user),
    )


@router.post("/customer/login", response_model=CustomerTokenResponse)
def customer_login(
    payload: CustomerLoginRequest,
    db: Session = Depends(get_db),
) -> CustomerTokenResponse:
    cleaned_mobile = payload.mobile.strip()
    user = db.scalars(
        select(User)
        .options(selectinload(User.customer_profile))
        .where(User.mobile == cleaned_mobile)
    ).first()

    if user is None:
        verify_password(payload.password, _TIMING_SAFE_DUMMY_HASH)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password",
        )

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid mobile number or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    if user.role != "customer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Customer privileges required",
        )

    expires_delta = timedelta(minutes=settings.jwt_access_token_expire_minutes)
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
        expires_delta=expires_delta,
    )

    return CustomerTokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in=int(expires_delta.total_seconds()),
        user=CustomerUserResponse.model_validate(user),
    )


@router.get("/customer/me", response_model=CustomerUserResponse)
def customer_me(
    current_customer: User = Depends(require_customer),
    db: Session = Depends(get_db),
) -> CustomerUserResponse:
    user = db.scalars(
        select(User)
        .options(selectinload(User.customer_profile))
        .where(User.id == current_customer.id)
    ).first()
    if user is None:
        raise HTTPException(status_code=404, detail="Customer account not found")
    return CustomerUserResponse.model_validate(user)
