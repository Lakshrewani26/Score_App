from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.core.security import require_admin
from app.db.session import check_database_connection, get_db
from app.models import PointsRule, User
from app.schemas.admin_settings import (
    VALID_CATEGORIES,
    PointsRuleCreate,
    PointsRuleListResponse,
    PointsRuleResponse,
    PointsRuleStatusUpdate,
    PointsRuleUpdate,
    SystemInfoResponse,
    _normalize_dt,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/admin", tags=["admin_settings"])


def _to_rule_response(rule: PointsRule) -> PointsRuleResponse:
    return PointsRuleResponse(
        id=rule.id,
        rule_name=rule.rule_name,
        rule_description=rule.rule_description,
        category=rule.category,
        points_awarded=rule.points_awarded,
        points_required=rule.points_required,
        min_transaction_value=rule.min_transaction_value,
        max_transaction_value=rule.max_transaction_value,
        effective_from=rule.effective_from,
        effective_to=rule.effective_to,
        is_active=rule.is_active,
        created_at=rule.created_at,
        updated_at=rule.updated_at,
        created_by=rule.created_by,
        updated_by=rule.updated_by,
        created_by_name=rule.creator.name if rule.creator else None,
        updated_by_name=rule.updater.name if rule.updater else None,
    )


# -----------------------------------------------------------------------------
# System Information Endpoints (Read-Only)
# -----------------------------------------------------------------------------


@router.get(
    "/settings/system-info",
    response_model=SystemInfoResponse,
)
@router.get(
    "/settings",
    response_model=SystemInfoResponse,
)
def get_system_info(
    current_admin: User = Depends(require_admin),
) -> SystemInfoResponse:
    """
    Retrieve read-only system metadata.
    Strictly excludes all secrets, database URLs, and JWT secret keys.
    """
    db_status = "connected"
    try:
        check_database_connection()
    except Exception:
        db_status = "degraded"

    return SystemInfoResponse(
        app_name=settings.app_name,
        environment=settings.environment,
        api_version="1.0.0 (Phase 7)",
        database_status=db_status,
    )


# -----------------------------------------------------------------------------
# Points System Rules Endpoints
# -----------------------------------------------------------------------------


@router.get(
    "/points-rules",
    response_model=PointsRuleListResponse,
)
def list_points_rules(
    category: str | None = Query(default=None),
    is_active: bool | None = Query(default=None),
    search: str | None = Query(default=None),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleListResponse:
    """
    List owner-controlled points rules with optional filtering and search.
    Eager-loads creator and updater relationships to avoid N+1 queries.
    """
    filters = []

    if category is not None:
        cat_clean = category.strip().lower()
        if cat_clean and cat_clean != "all":
            if cat_clean not in VALID_CATEGORIES:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Unsupported category '{category}'. Must be one of: {', '.join(VALID_CATEGORIES)}",
                )
            filters.append(PointsRule.category == cat_clean)

    if is_active is not None:
        filters.append(PointsRule.is_active == is_active)

    if search:
        pattern = f"%{search.strip()}%"
        filters.append(
            PointsRule.rule_name.ilike(pattern) | PointsRule.rule_description.ilike(pattern)
        )

    query = (
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(*filters)
        .order_by(PointsRule.is_active.desc(), PointsRule.created_at.desc(), PointsRule.id.desc())
    )

    rules = db.scalars(query).all()
    items = [_to_rule_response(r) for r in rules]

    return PointsRuleListResponse(items=items, total=len(items))


@router.post(
    "/points-rules",
    response_model=PointsRuleResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_points_rule(
    payload: PointsRuleCreate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleResponse:
    """
    Create a new owner-controlled points rule.
    Validates all structured fields and attributes creation to authenticated admin.
    """
    try:
        rule = PointsRule(
            rule_name=payload.rule_name,
            rule_description=payload.rule_description,
            category=payload.category,
            points_awarded=payload.points_awarded,
            points_required=payload.points_required,
            min_transaction_value=payload.min_transaction_value,
            max_transaction_value=payload.max_transaction_value,
            effective_from=payload.effective_from,
            effective_to=payload.effective_to,
            is_active=payload.is_active,
            created_by=current_admin.id,
            updated_by=current_admin.id,
        )
        db.add(rule)
        db.commit()
    except Exception:
        db.rollback()
        raise

    fresh_rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == rule.id)
    )
    return _to_rule_response(fresh_rule)


@router.get(
    "/points-rules/{rule_id}",
    response_model=PointsRuleResponse,
)
def get_points_rule_detail(
    rule_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleResponse:
    """
    Retrieve full details of a points rule by its ID.
    """
    rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == rule_id)
    )
    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Points rule not found",
        )

    return _to_rule_response(rule)


@router.patch(
    "/points-rules/{rule_id}",
    response_model=PointsRuleResponse,
)
@router.post(
    "/points-rules/{rule_id}/update",
    response_model=PointsRuleResponse,
)
def update_points_rule(
    rule_id: int,
    payload: PointsRuleUpdate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleResponse:
    """
    Update editable fields of an existing points rule.
    Validates cross-field constraints against both incoming and existing state.
    """
    rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == rule_id)
    )
    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Points rule not found",
        )

    updates = payload.model_dump(exclude_unset=True)

    # Cross-field validation against merged values
    merged_min_val = (
        updates["min_transaction_value"]
        if "min_transaction_value" in updates
        else rule.min_transaction_value
    )
    merged_max_val = (
        updates["max_transaction_value"]
        if "max_transaction_value" in updates
        else rule.max_transaction_value
    )
    if merged_min_val is not None and merged_max_val is not None and merged_min_val > merged_max_val:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Minimum transaction value cannot exceed maximum transaction value",
        )

    merged_start = (
        updates["effective_from"] if "effective_from" in updates else rule.effective_from
    )
    merged_end = (
        updates["effective_to"] if "effective_to" in updates else rule.effective_to
    )
    start_norm = _normalize_dt(merged_start)
    end_norm = _normalize_dt(merged_end)
    if start_norm is not None and end_norm is not None and start_norm > end_norm:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Effective start date cannot be after effective end date",
        )

    try:
        for field, value in updates.items():
            setattr(rule, field, value)

        rule.updated_by = current_admin.id
        db.commit()
    except Exception:
        db.rollback()
        raise

    fresh_rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == rule.id)
    )
    return _to_rule_response(fresh_rule)


@router.post(
    "/points-rules/{rule_id}/status",
    response_model=PointsRuleResponse,
)
@router.patch(
    "/points-rules/{rule_id}/status",
    response_model=PointsRuleResponse,
)
def update_points_rule_status(
    rule_id: int,
    payload: PointsRuleStatusUpdate,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleResponse:
    """
    Activate or deactivate a points rule.
    Rules are never hard-deleted from the database to preserve historical auditability.
    """
    rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == rule_id)
    )
    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Points rule not found",
        )

    try:
        rule.is_active = payload.is_active
        rule.updated_by = current_admin.id
        db.commit()
    except Exception:
        db.rollback()
        raise

    fresh_rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == rule.id)
    )
    return _to_rule_response(fresh_rule)
