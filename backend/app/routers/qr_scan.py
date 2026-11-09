from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import Any, Optional
from urllib.parse import parse_qs, urlparse

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import case, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.security import get_current_active_user
from app.db.session import get_db
from app.models import PointTransaction, PointsRule, QrCode, User
from app.schemas.admin_settings import _normalize_dt
from app.services.points_service import get_user_points_balance

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/qr", tags=["qr-scanning"])


class QrScanRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")

    code_data: Optional[str] = Field(default=None, max_length=1000, description="Scanned QR code URL or raw token")
    token: Optional[str] = Field(default=None, max_length=128, description="Raw QR code token")
    idempotency_key: Optional[str] = Field(default=None, max_length=128, description="Client idempotency key")

    @model_validator(mode="before")
    @classmethod
    def resolve_token_or_code(cls, data: Any) -> Any:
        if isinstance(data, dict):
            raw = data.get("code_data") or data.get("token")
            if not raw or not str(raw).strip():
                raise ValueError("Either code_data or token must be provided and non-empty")
            data["code_data"] = str(raw).strip()
        return data


class QrScanResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    success: bool
    message: str
    points_awarded: int
    new_balance: int
    qr_token: str
    qr_type: str
    rule_id: int
    rule_name: str
    rule_version: int
    scanned_at: datetime
    is_idempotent_replay: bool = False


class PointTransactionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    qr_code_id: int
    qr_token: str
    points_rule_id: int
    points_rule_name: Optional[str] = None
    points_rule_version: Optional[int] = None
    points_awarded: int
    qr_type: str
    transaction_type: str
    idempotency_key: Optional[str] = None
    created_at: datetime


def _extract_token(raw_data: str) -> str:
    cleaned = raw_data.strip()
    if "token=" in cleaned:
        try:
            parsed = urlparse(cleaned)
            params = parse_qs(parsed.query)
            if "token" in params and params["token"]:
                return params["token"][0].strip().upper()
        except Exception:
            pass
    return cleaned.upper()


@router.post(
    "/scan",
    response_model=QrScanResponse,
    status_code=status.HTTP_200_OK,
    summary="Scan QR code and award loyalty points",
)
def scan_qr_code(
    payload: QrScanRequest,
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
) -> QrScanResponse:
    """
    Scans a product/loyalty QR code and awards points according to the applicable active rule.
    Guarantees strict idempotency and concurrency protection against duplicate point awards.
    """
    now = datetime.now(timezone.utc)

    # 1. Check idempotency replay if client provided idempotency_key
    if payload.idempotency_key:
        existing_tx = db.scalar(
            select(PointTransaction)
            .options(selectinload(PointTransaction.points_rule))
            .where(
                PointTransaction.idempotency_key == payload.idempotency_key,
                PointTransaction.user_id == current_user.id,
            )
        )
        if existing_tx:
            balance = get_user_points_balance(
                db, current_user.id, role=current_user.role
            ).current_balance
            rule = existing_tx.points_rule
            return QrScanResponse(
                success=True,
                message="Duplicate request recognized: points previously awarded for this scan.",
                points_awarded=existing_tx.points_awarded,
                new_balance=balance,
                qr_token=existing_tx.qr_token,
                qr_type=existing_tx.qr_type,
                rule_id=rule.id if rule else existing_tx.points_rule_id,
                rule_name=rule.rule_name if rule else "Loyalty Scan Rule",
                rule_version=rule.version if rule else 1,
                scanned_at=existing_tx.created_at,
                is_idempotent_replay=True,
            )

    token = _extract_token(payload.code_data)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid QR code data: token missing or empty.",
        )

    if len(token) > 64:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code token not found.",
        )

    # 2. Verify caller role eligibility
    role = (current_user.role or "").lower()
    if role not in ("customer", "partner"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Users with role '{current_user.role}' are not eligible to scan QR codes for loyalty points.",
        )

    # 3. Lock and retrieve QrCode row
    qr_code = db.scalar(
        select(QrCode)
        .where(QrCode.token == token)
        .with_for_update()
    )

    if not qr_code:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code token not found.",
        )

    # 4. Validate QR code type: only 'product' QR codes are eligible for loyalty points scanning
    if qr_code.qr_type != "product":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Inappropriate QR code type: '{qr_code.qr_type}' QR codes cannot be scanned for loyalty points.",
        )

    # 5. Validate code status
    if qr_code.status == "redeemed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This QR code has already been scanned and redeemed.",
        )

    if qr_code.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"This QR code is not valid for scanning (status: {qr_code.status}).",
        )

    exp = _normalize_dt(qr_code.expires_at)
    if exp and exp < now:
        qr_code.status = "expired"
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This QR code has expired.",
        )

    # 6. Resolve applicable active loyalty rule
    # Roles have dedicated QR scan rules: 'customer_qr_scan' for Customer, 'partner_qr_scan' for Partner.
    # Fallback to 'product_qr_scan' if role-specific rule is not configured.
    if role == "customer":
        target_categories = ["customer_qr_scan", "product_qr_scan"]
        primary_cat = "customer_qr_scan"
    else:  # partner
        target_categories = ["partner_qr_scan", "product_qr_scan"]
        primary_cat = "partner_qr_scan"

    rule_query = (
        select(PointsRule)
        .where(
            PointsRule.category.in_(target_categories),
            PointsRule.is_active.is_(True),
            (PointsRule.effective_from.is_(None) | (PointsRule.effective_from <= now)),
            (PointsRule.effective_to.is_(None) | (PointsRule.effective_to >= now)),
        )
        .order_by(
            case((PointsRule.category == primary_cat, 1), else_=2),
            PointsRule.version.desc(),
            PointsRule.id.desc(),
        )
    )

    rule = db.scalar(rule_query)
    if not rule or not rule.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No active loyalty point rule is currently in effect for {role} QR scans.",
        )

    # Check effective date constraints
    eff_from = _normalize_dt(rule.effective_from)
    eff_to = _normalize_dt(rule.effective_to)

    if eff_from and eff_from > now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Loyalty rule '{rule.rule_name}' is not yet effective (starts {eff_from.isoformat()}).",
        )
    if eff_to and eff_to < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Loyalty rule '{rule.rule_name}' has expired.",
        )

    # 7. Compute points to award dynamically
    points_awarded = rule.points_awarded
    if (points_awarded is None or points_awarded <= 0) and qr_code.points_awarded and qr_code.points_awarded > 0:
        points_awarded = qr_code.points_awarded
    if points_awarded is None or points_awarded <= 0:
        if rule.point_value is not None and rule.point_value > 0:
            points_awarded = int(rule.point_value * 100)
        elif rule.conversion_rate is not None and rule.conversion_rate > 0:
            points_awarded = int(rule.conversion_rate * 100)
        else:
            points_awarded = 10

    # 8. Apply atomic status change and create point transaction
    qr_code.status = "redeemed"
    qr_code.redeemed_by = current_user.id
    qr_code.redeemed_at = now
    qr_code.points_awarded = points_awarded

    transaction = PointTransaction(
        user_id=current_user.id,
        qr_code_id=qr_code.id,
        qr_token=qr_code.token,
        points_rule_id=rule.id,
        points_awarded=points_awarded,
        qr_type=qr_code.qr_type,
        transaction_type="qr_scan",
        idempotency_key=payload.idempotency_key,
    )
    db.add(transaction)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This QR code has already been scanned and redeemed.",
        )

    # 7. Compute updated balance via unified points balance service
    balance = get_user_points_balance(db, current_user.id, role=role).current_balance

    return QrScanResponse(
        success=True,
        message=f"QR code scanned successfully! Awarded {points_awarded} loyalty points.",
        points_awarded=points_awarded,
        new_balance=balance,
        qr_token=qr_code.token,
        qr_type=qr_code.qr_type,
        rule_id=rule.id,
        rule_name=rule.rule_name,
        rule_version=rule.version,
        scanned_at=now,
    )


@router.get(
    "/transactions",
    response_model=list[PointTransactionResponse],
    summary="List point transaction history for current user",
)
def get_user_point_transactions(
    current_user: User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
) -> list[PointTransactionResponse]:
    """
    Returns transaction history preserving the exact rule version that was applied.
    """
    txs = db.scalars(
        select(PointTransaction)
        .options(selectinload(PointTransaction.points_rule))
        .where(PointTransaction.user_id == current_user.id)
        .order_by(PointTransaction.created_at.desc(), PointTransaction.id.desc())
    ).all()

    return [
        PointTransactionResponse(
            id=tx.id,
            user_id=tx.user_id,
            qr_code_id=tx.qr_code_id,
            qr_token=tx.qr_token,
            points_rule_id=tx.points_rule_id,
            points_rule_name=tx.points_rule.rule_name if tx.points_rule else None,
            points_rule_version=tx.points_rule.version if tx.points_rule else None,
            points_awarded=tx.points_awarded,
            qr_type=tx.qr_type,
            transaction_type=tx.transaction_type,
            idempotency_key=tx.idempotency_key,
            created_at=tx.created_at,
        )
        for tx in txs
    ]
