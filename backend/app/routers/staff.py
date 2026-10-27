from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.security import require_staff
from app.db.session import get_db
from app.models import PartnerProfile, StaffPartnerAssignment, StaffProfile, User
from app.schemas.auth import StaffUserResponse
from app.schemas.staff import StaffAssignedPartnerResponse

router = APIRouter(prefix="/api/v1/staff", tags=["staff"])


@router.get("/me", response_model=StaffUserResponse)
def get_current_staff(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> StaffUserResponse:
    profile = db.scalar(
        select(StaffProfile).where(StaffProfile.user_id == current_staff.id)
    )
    if profile is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff profile not found",
        )
    return StaffUserResponse(
        id=current_staff.id,
        name=current_staff.name,
        mobile=current_staff.mobile,
        role=current_staff.role,
        is_active=current_staff.is_active,
        staff_id=profile.staff_id,
        created_at=current_staff.created_at,
    )


@router.get("/partners", response_model=list[StaffAssignedPartnerResponse])
def list_assigned_partners(
    current_staff: User = Depends(require_staff),
    db: Session = Depends(get_db),
) -> list[StaffAssignedPartnerResponse]:
    partners = db.scalars(
        select(PartnerProfile)
        .join(
            StaffPartnerAssignment,
            StaffPartnerAssignment.partner_id == PartnerProfile.user_id,
        )
        .join(User, User.id == PartnerProfile.user_id)
        .options(selectinload(PartnerProfile.user))
        .where(
            StaffPartnerAssignment.staff_id == current_staff.id,
            StaffPartnerAssignment.is_active.is_(True),
            User.is_active.is_(True),
            User.role == "partner",
        )
        .order_by(PartnerProfile.business_name, PartnerProfile.user_id)
    ).all()
    return [
        StaffAssignedPartnerResponse(
            id=profile.user.id,
            name=profile.user.name,
            mobile=profile.user.mobile,
            business_name=profile.business_name,
            business_address=profile.business_address,
            partner_code=profile.partner_code,
        )
        for profile in partners
    ]
