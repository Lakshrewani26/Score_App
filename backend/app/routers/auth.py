from __future__ import annotations

from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token, require_partner, verify_password
from app.db.session import get_db
from app.models import StaffProfile, User
from app.schemas.auth import (
    AdminLoginRequest,
    AdminUserResponse,
    PartnerLoginRequest,
    PartnerTokenResponse,
    PartnerUserResponse,
    StaffLoginRequest,
    StaffTokenResponse,
    StaffUserResponse,
    TokenResponse,
)
from sqlalchemy.orm import selectinload

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
