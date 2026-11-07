from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.core.security import require_admin
from app.db.session import check_database_connection, get_db
from app.models import PointsRule, User
from app.schemas.admin_settings import (
    VALID_CATEGORIES,
    PointsRuleCreate,
    PointsRuleHistoryResponse,
    PointsRuleListResponse,
    PointsRuleResponse,
    PointsRuleStatusUpdate,
    PointsRuleUpdate,
    SystemInfoResponse,
    _normalize_dt,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/admin", tags=["admin_settings"])


def _compute_effective_status(rule: PointsRule, now: datetime) -> str:
    """
    Computes rule runtime status without persisting unnecessary state.
    Distinguishes:
    - 'currently_effective': active rule whose effective window contains current wall-clock time
    - 'future_scheduled': active rule whose effective_from is in the future
    - 'expired': active rule whose effective_to has passed
    - 'inactive': deactivated rule
    """
    if not rule.is_active:
        return "inactive"
    eff_from = _normalize_dt(rule.effective_from)
    eff_to = _normalize_dt(rule.effective_to)
    if eff_from and eff_from > now:
        return "future_scheduled"
    if eff_to and eff_to < now:
        return "expired"
    return "currently_effective"


def _to_rule_response(rule: PointsRule, now: datetime | None = None) -> PointsRuleResponse:
    if now is None:
        now = datetime.now(timezone.utc)
    eff_status = _compute_effective_status(rule, now)
    return PointsRuleResponse(
        id=rule.id,
        rule_name=rule.rule_name,
        rule_description=rule.rule_description,
        category=rule.category,
        points_awarded=rule.points_awarded,
        points_required=rule.points_required,
        conversion_rate=rule.conversion_rate,
        point_value=rule.point_value,
        min_transaction_value=rule.min_transaction_value,
        max_transaction_value=rule.max_transaction_value,
        effective_from=rule.effective_from,
        effective_to=rule.effective_to,
        is_active=rule.is_active,
        is_current=getattr(rule, "is_current", True),
        version=rule.version,
        parent_rule_id=rule.parent_rule_id,
        effective_status=eff_status,
        is_currently_effective=(eff_status == "currently_effective"),
        is_future_scheduled=(eff_status == "future_scheduled"),
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
    include_history: bool = Query(default=False, description="Whether to include historical snapshot rules"),
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleListResponse:
    """
    List owner-controlled points rules with optional filtering and search.
    Eager-loads creator and updater relationships to avoid N+1 queries.
    """
    filters = []

    if not include_history:
        filters.append(PointsRule.is_current.is_(True))

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
            conversion_rate=payload.conversion_rate,
            point_value=payload.point_value,
            min_transaction_value=payload.min_transaction_value,
            max_transaction_value=payload.max_transaction_value,
            effective_from=payload.effective_from,
            effective_to=payload.effective_to,
            is_active=payload.is_active,
            is_current=True,
            version=1,
            parent_rule_id=None,
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
@router.put(
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
    Publish a new immutable version of an existing points rule.
    - Previously published rule versions remain untouched and immutable.
    - Existing point transactions continue referencing their original rule version.
    - The new version is created as a new record with version = latest_version + 1.
    - Future-dated versions leave the currently valid rule active until handover.
    - Root-level row locking serializes concurrent version creation.
    """
    rule = db.scalar(
        select(PointsRule)
        .where(PointsRule.id == rule_id)
    )
    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Points rule not found",
        )

    root_id = rule.parent_rule_id or rule.id

    # 1. Lock the root rule to serialize concurrent version updates for this lineage
    root_rule = db.scalar(
        select(PointsRule)
        .where(PointsRule.id == root_id)
        .with_for_update()
    )
    if root_rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Points rule lineage root not found",
        )

    # 2. Fetch all existing versions in this lineage with row lock
    lineage_rules = db.scalars(
        select(PointsRule)
        .where((PointsRule.id == root_id) | (PointsRule.parent_rule_id == root_id))
        .order_by(PointsRule.version.desc(), PointsRule.id.desc())
        .with_for_update()
    ).all()

    latest_rule = lineage_rules[0]
    latest_version_num = latest_rule.version

    updates = payload.model_dump(exclude_unset=True)

    # 3. Cross-field validation against merged values from latest version
    merged_min_val = (
        updates["min_transaction_value"]
        if "min_transaction_value" in updates
        else latest_rule.min_transaction_value
    )
    merged_max_val = (
        updates["max_transaction_value"]
        if "max_transaction_value" in updates
        else latest_rule.max_transaction_value
    )
    if merged_min_val is not None and merged_max_val is not None and merged_min_val > merged_max_val:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Minimum transaction value cannot exceed maximum transaction value",
        )

    merged_start = (
        updates["effective_from"] if "effective_from" in updates else latest_rule.effective_from
    )
    merged_end = (
        updates["effective_to"] if "effective_to" in updates else latest_rule.effective_to
    )
    start_norm = _normalize_dt(merged_start)
    end_norm = _normalize_dt(merged_end)
    if start_norm is not None and end_norm is not None and start_norm > end_norm:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Effective start date cannot be after effective end date",
        )

    now = datetime.now(timezone.utc)
    new_effective_from = start_norm
    new_effective_to = end_norm

    # 4. Handle effective date handover without premature deactivation
    if new_effective_from is None or new_effective_from <= now:
        # Effective immediately: end previous rule's validity now
        latest_rule.effective_to = new_effective_from or now
    else:
        # Future-dated: handover at new_effective_from; previous rule remains active until then!
        latest_rule.effective_to = new_effective_from

    # 5. Mark older versions as not current
    for r in lineage_rules:
        r.is_current = False

    # 6. Create brand new immutable rule record
    new_version_num = latest_version_num + 1
    new_rule = PointsRule(
        rule_name=updates.get("rule_name", latest_rule.rule_name),
        rule_description=updates.get("rule_description", latest_rule.rule_description),
        category=updates.get("category", latest_rule.category),
        points_awarded=updates.get("points_awarded", latest_rule.points_awarded),
        points_required=updates.get("points_required", latest_rule.points_required),
        conversion_rate=updates.get("conversion_rate", latest_rule.conversion_rate),
        point_value=updates.get("point_value", latest_rule.point_value),
        min_transaction_value=updates.get("min_transaction_value", latest_rule.min_transaction_value),
        max_transaction_value=updates.get("max_transaction_value", latest_rule.max_transaction_value),
        effective_from=new_effective_from,
        effective_to=new_effective_to,
        is_active=updates.get("is_active", latest_rule.is_active),
        version=new_version_num,
        parent_rule_id=root_id,
        is_current=True,
        created_by=current_admin.id,
        updated_by=current_admin.id,
    )
    db.add(new_rule)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A concurrent update created this rule version. Please refresh and try again.",
        )
    except Exception:
        db.rollback()
        raise

    fresh_rule = db.scalar(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where(PointsRule.id == new_rule.id)
    )
    return _to_rule_response(fresh_rule)


@router.get(
    "/points-rules/{rule_id}/history",
    response_model=PointsRuleHistoryResponse,
)
def get_points_rule_history(
    rule_id: int,
    current_admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> PointsRuleHistoryResponse:
    """
    Retrieve full historical lineage of a rule across all versions.
    """
    rule = db.scalar(
        select(PointsRule)
        .where(PointsRule.id == rule_id)
    )
    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Points rule not found",
        )

    root_id = rule.parent_rule_id or rule.id
    history_rules = db.scalars(
        select(PointsRule)
        .options(
            selectinload(PointsRule.creator),
            selectinload(PointsRule.updater),
        )
        .where((PointsRule.id == root_id) | (PointsRule.parent_rule_id == root_id))
        .order_by(PointsRule.version.desc(), PointsRule.id.desc())
    ).all()

    now = datetime.now(timezone.utc)
    current_rule = next((r for r in history_rules if r.is_current), history_rules[0])
    effective_rule = next(
        (
            r for r in history_rules
            if r.is_active
            and (r.effective_from is None or _normalize_dt(r.effective_from) <= now)
            and (r.effective_to is None or _normalize_dt(r.effective_to) >= now)
        ),
        None,
    )
    items = [_to_rule_response(r, now) for r in history_rules]

    return PointsRuleHistoryResponse(
        rule_id=rule.id,
        rule_name=current_rule.rule_name,
        current_version=current_rule.version,
        latest_version=current_rule.version,
        effective_version=effective_rule.version if effective_rule else None,
        history=items,
    )


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
