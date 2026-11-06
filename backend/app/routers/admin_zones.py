from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import require_admin
from app.db.session import get_db
from app.models import PartnerProfile, User, Zone
from app.schemas.admin_zones import (
    ZoneCreate,
    ZoneListResponse,
    ZoneResponse,
    ZoneStatusUpdate,
    ZoneUpdate,
)

router = APIRouter(prefix="/api/v1/admin/zones", tags=["admin-zones"])


def _to_zone_response(zone: Zone, db: Session) -> ZoneResponse:
    partner_count = db.scalar(
        select(func.count(PartnerProfile.user_id)).where(PartnerProfile.zone_id == zone.id)
    ) or 0
    return ZoneResponse(
        id=zone.id,
        name=zone.name,
        description=zone.description,
        is_active=zone.is_active,
        created_at=zone.created_at,
        updated_at=zone.updated_at,
        partner_count=partner_count,
    )


@router.get("", response_model=ZoneListResponse)
def list_zones(
    is_active: Optional[bool] = Query(default=None),
    search: Optional[str] = Query(default=None),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ZoneListResponse:
    """
    List zones for Admin with optional status and name search filters.
    """
    query = select(Zone).order_by(Zone.name.asc(), Zone.id.asc())

    if is_active is not None:
        query = query.where(Zone.is_active.is_(is_active))

    if search:
        clean_search = search.strip()
        if clean_search:
            pattern = f"%{clean_search}%"
            query = query.where(Zone.name.ilike(pattern) | Zone.description.ilike(pattern))

    zones = db.scalars(query).all()
    items = [_to_zone_response(z, db) for z in zones]
    return ZoneListResponse(items=items, total=len(items))


@router.post("", response_model=ZoneResponse, status_code=status.HTTP_201_CREATED)
def create_zone(
    payload: ZoneCreate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ZoneResponse:
    """
    Create a new Zone. Rejects duplicate names with HTTP 409 Conflict.
    """
    clean_name = payload.name.strip()
    existing = db.scalar(
        select(Zone.id).where(func.lower(Zone.name) == func.lower(clean_name))
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Zone with name '{clean_name}' already exists",
        )

    zone = Zone(
        name=clean_name,
        description=payload.description.strip() if payload.description else None,
        is_active=payload.is_active,
    )

    try:
        db.add(zone)
        db.commit()
        db.refresh(zone)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Zone with name '{clean_name}' already exists",
        )

    return _to_zone_response(zone, db)


@router.get("/{zone_id}", response_model=ZoneResponse)
def get_zone_detail(
    zone_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ZoneResponse:
    """
    Retrieve Zone details by ID.
    """
    zone = db.get(Zone, zone_id)
    if zone is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Zone not found",
        )
    return _to_zone_response(zone, db)


@router.patch("/{zone_id}", response_model=ZoneResponse)
@router.post("/{zone_id}/update", response_model=ZoneResponse)
def update_zone(
    zone_id: int,
    payload: ZoneUpdate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ZoneResponse:
    """
    Update Zone details (name, description, is_active).
    """
    zone = db.get(Zone, zone_id)
    if zone is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Zone not found",
        )

    updates = payload.model_dump(exclude_unset=True)

    if "name" in updates and updates["name"]:
        clean_name = updates["name"].strip()
        existing = db.scalar(
            select(Zone.id).where(
                func.lower(Zone.name) == func.lower(clean_name),
                Zone.id != zone_id,
            )
        )
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Zone with name '{clean_name}' already exists",
            )
        zone.name = clean_name

    if "description" in updates:
        desc = updates["description"]
        zone.description = desc.strip() if desc else None

    if "is_active" in updates and updates["is_active"] is not None:
        zone.is_active = updates["is_active"]

    try:
        db.commit()
        db.refresh(zone)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Zone update failed due to constraint violation",
        )

    return _to_zone_response(zone, db)


@router.post("/{zone_id}/status", response_model=ZoneResponse)
def update_zone_status(
    zone_id: int,
    payload: ZoneStatusUpdate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ZoneResponse:
    """
    Activate or deactivate a Zone.
    """
    zone = db.get(Zone, zone_id)
    if zone is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Zone not found",
        )

    zone.is_active = payload.is_active
    db.commit()
    db.refresh(zone)

    return _to_zone_response(zone, db)
