from __future__ import annotations

from datetime import datetime, timezone
import logging
from typing import Optional
from urllib.parse import parse_qs, urlparse

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from app.core.security import require_partner
from app.db.session import get_db
from app.models import PointTransfer, PointsRule, QrCode, User
from app.schemas.admin_settings import _normalize_dt
from app.schemas.partner import (
    PartnerPointHistoryItem,
    PartnerPointsHistoryResponse,
    PartnerTransferRequest,
    PartnerTransferResponse,
)
from app.services.points_service import (
    get_partner_points_history,
    get_user_points_balance,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/partner", tags=["partner"])


def _extract_token(raw_data: str) -> str:
    cleaned = raw_data.strip()
    if "token=" in cleaned:
        try:
            parsed = urlparse(cleaned)
            params = parse_qs(parsed.query)
            if "token" in params and params["token"]:
                return params["token"][0].strip()
        except Exception:
            pass
    return cleaned


@router.post(
    "/transfers",
    response_model=PartnerTransferResponse,
    status_code=status.HTTP_200_OK,
    summary="Execute Partner to Staff points transfer",
)
@router.post(
    "/transfer",
    response_model=PartnerTransferResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def transfer_points_to_staff(
    payload: PartnerTransferRequest,
    current_partner: User = Depends(require_partner),
    db: Session = Depends(get_db),
) -> PartnerTransferResponse:
    """
    Executes an atomic points transfer from the authenticated Partner to a Staff recipient.
    - Resolves recipient exclusively via verified active Staff QR code.
    - Requires active Partner account and sufficient points balance.
    - Enforces configured Partner->Staff transfer points rule and limits.
    - Locks sender row during transaction to guarantee concurrency safety.
    - Idempotency-protected: duplicate requests replay original result without double debit.
    """
    # 1. Amount validation
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transfer amount must be a positive integer greater than zero.",
        )

    # 2. Extract and format QR token
    raw_input = (payload.token or payload.code_data or "").strip()
    if not raw_input:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A valid QR code token must be provided.",
        )

    token = _extract_token(raw_input)
    if len(token) > 64:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff QR code token not found.",
        )

    # 3. Fast-path Idempotency check: see if idempotency key was already recorded
    existing_transfer = db.scalar(
        select(PointTransfer)
        .options(
            selectinload(PointTransfer.recipient).selectinload(User.staff_profile),
            selectinload(PointTransfer.sender),
            selectinload(PointTransfer.qr_code),
        )
        .where(PointTransfer.idempotency_key == payload.idempotency_key)
    )

    if existing_transfer is not None:
        # 3a. Validate cross-partner isolation
        if existing_transfer.sender_id != current_partner.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Idempotency key has already been used for a different transfer payload.",
            )

        # 3b. Validate transfer amount
        if existing_transfer.amount != payload.amount:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Idempotency key has already been used for a different transfer payload.",
            )

        # 3c. Validate recipient matching against stored transfer and QR relationship
        is_same_recipient = False
        stored_qr = existing_transfer.qr_code
        if stored_qr:
            if (
                stored_qr.token == token
                or stored_qr.token == token.upper()
                or stored_qr.token == token.lower()
                or stored_qr.code_data == raw_input
            ):
                is_same_recipient = True

        if not is_same_recipient:
            # Fallback check against qr_codes table in case qr_code was updated or unlinked
            matching_qr = db.scalar(
                select(QrCode).where(
                    (QrCode.token == token)
                    | (QrCode.token == token.upper())
                    | (QrCode.token == token.lower())
                )
            )
            if matching_qr and matching_qr.target_user_id == existing_transfer.recipient_id:
                is_same_recipient = True

        if not is_same_recipient:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Idempotency key has already been used for a different transfer payload.",
            )

        # 3d. Return replayed transfer confirmation (historical QR expiration or staff deactivation does not block replay)
        sender_bal = get_user_points_balance(db, current_partner.id, role="partner").current_balance
        recip_bal = get_user_points_balance(db, existing_transfer.recipient_id, role="staff").current_balance
        recip = existing_transfer.recipient
        recip_badge_id = (
            recip.staff_profile.staff_id
            if recip and recip.staff_profile
            else None
        )
        return PartnerTransferResponse(
            transfer_id=existing_transfer.id,
            amount=existing_transfer.amount,
            sender_id=existing_transfer.sender_id,
            recipient_id=existing_transfer.recipient_id,
            recipient_name=recip.name if recip else None,
            recipient_staff_id=recip_badge_id,
            created_at=existing_transfer.created_at,
            sender_balance=sender_bal,
            recipient_balance=recip_bal,
            is_idempotent_replay=True,
        )

    # 4. Lock Partner row to serialize concurrent transactions for this sender
    partner = db.scalar(
        select(User)
        .where(User.id == current_partner.id)
        .with_for_update()
    )
    if not partner or not partner.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Partner account is deactivated.",
        )

    # 5. Resolve Staff QR code
    qr_code = db.scalar(
        select(QrCode)
        .options(
            selectinload(QrCode.target_user).selectinload(User.staff_profile)
        )
        .where(
            (QrCode.token == token)
            | (QrCode.token == token.upper())
            | (QrCode.token == token.lower())
        )
    )

    if qr_code is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Staff QR code token not found.",
        )

    if qr_code.qr_type != "staff":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Inappropriate QR code type: '{qr_code.qr_type}' QR codes cannot be used for Staff point transfers.",
        )

    if qr_code.status != "active":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"This QR code is not active (status: {qr_code.status}).",
        )

    now = datetime.now(timezone.utc)
    exp = _normalize_dt(qr_code.expires_at)
    if exp and exp < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This Staff QR code has expired.",
        )

    if qr_code.target_user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This QR code is not assigned to any staff member.",
        )

    target_user = qr_code.target_user
    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assigned staff user not found.",
        )

    if target_user.role != "staff":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Assigned user does not hold the 'staff' role (current role: '{target_user.role}').",
        )

    if not target_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Assigned staff user account is inactive.",
        )

    if target_user.id == current_partner.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Sender and recipient cannot be the same user.",
        )

    # 6. Resolve Partner -> Staff transfer rule
    rule = db.scalar(
        select(PointsRule)
        .where(
            PointsRule.category == "partner_to_staff_transfer",
            PointsRule.is_active.is_(True),
            (PointsRule.effective_from.is_(None) | (PointsRule.effective_from <= now)),
            (PointsRule.effective_to.is_(None) | (PointsRule.effective_to >= now)),
        )
        .order_by(
            PointsRule.is_current.desc(),
            PointsRule.version.desc(),
            PointsRule.id.desc(),
        )
    )

    if rule is None or not rule.is_active:
        any_rule = db.scalar(
            select(PointsRule)
            .where(PointsRule.category == "partner_to_staff_transfer")
            .order_by(PointsRule.version.desc(), PointsRule.id.desc())
        )
        if any_rule and not any_rule.is_active:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Partner to Staff transfer points rule '{any_rule.rule_name}' is disabled.",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active Partner to Staff transfer rule is configured.",
        )

    # Validate rule effective dates
    eff_from = _normalize_dt(rule.effective_from)
    eff_to = _normalize_dt(rule.effective_to)
    if eff_from and eff_from > now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Points transfer rule '{rule.rule_name}' is not yet effective (starts {eff_from.isoformat()}).",
        )
    if eff_to and eff_to < now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Points transfer rule '{rule.rule_name}' has expired.",
        )

    # Enforce configured transfer restrictions
    if rule.min_transaction_value is not None and payload.amount < rule.min_transaction_value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Transfer amount {payload.amount} is below the minimum allowed transfer of {int(rule.min_transaction_value)} points.",
        )
    if rule.max_transaction_value is not None and payload.amount > rule.max_transaction_value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Transfer amount {payload.amount} exceeds the maximum allowed transfer of {int(rule.max_transaction_value)} points.",
        )
    if rule.points_required is not None and payload.amount < rule.points_required:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Transfer requires a minimum of {rule.points_required} points.",
        )

    # 8. Available balance validation inside database transaction
    partner_bal = get_user_points_balance(db, current_partner.id, role="partner")
    if partner_bal.current_balance < payload.amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Insufficient points balance. Current available balance is "
                f"{partner_bal.current_balance}, but transfer requires {payload.amount} points."
            ),
        )

    # 9. Insert PointTransfer ledger entry
    new_transfer = PointTransfer(
        sender_id=current_partner.id,
        recipient_id=target_user.id,
        amount=payload.amount,
        points_rule_id=rule.id,
        qr_code_id=qr_code.id,
        idempotency_key=payload.idempotency_key,
        remarks=f"Partner {current_partner.name} transferred {payload.amount} points to Staff {target_user.name}",
    )
    db.add(new_transfer)

    try:
        db.commit()
        db.refresh(new_transfer)
    except IntegrityError:
        db.rollback()
        # Handle concurrent race condition for idempotency key
        existing = db.scalar(
            select(PointTransfer)
            .options(
                selectinload(PointTransfer.recipient).selectinload(User.staff_profile)
            )
            .where(PointTransfer.idempotency_key == payload.idempotency_key)
        )
        if existing:
            if (
                existing.sender_id == current_partner.id
                and existing.recipient_id == target_user.id
                and existing.amount == payload.amount
            ):
                s_bal = get_user_points_balance(db, current_partner.id, role="partner").current_balance
                r_bal = get_user_points_balance(db, target_user.id, role="staff").current_balance
                stf_id = (
                    existing.recipient.staff_profile.staff_id
                    if existing.recipient and existing.recipient.staff_profile
                    else None
                )
                return PartnerTransferResponse(
                    transfer_id=existing.id,
                    amount=existing.amount,
                    sender_id=existing.sender_id,
                    recipient_id=existing.recipient_id,
                    recipient_name=existing.recipient.name if existing.recipient else None,
                    recipient_staff_id=stf_id,
                    created_at=existing.created_at,
                    sender_balance=s_bal,
                    recipient_balance=r_bal,
                    is_idempotent_replay=True,
                )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Idempotency key has already been used for a different transfer payload.",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Database integrity error during transfer creation.",
        )
    except Exception:
        db.rollback()
        raise

    # 10. Compute updated balances after commit
    updated_sender_bal = get_user_points_balance(db, current_partner.id, role="partner").current_balance
    updated_recip_bal = get_user_points_balance(db, target_user.id, role="staff").current_balance
    staff_badge_id = (
        target_user.staff_profile.staff_id
        if target_user.staff_profile
        else None
    )

    logger.info(
        "Partner ID %s transferred %d points to Staff ID %s (Transfer ID %d)",
        current_partner.id,
        payload.amount,
        target_user.id,
        new_transfer.id,
    )

    return PartnerTransferResponse(
        transfer_id=new_transfer.id,
        amount=new_transfer.amount,
        sender_id=new_transfer.sender_id,
        recipient_id=new_transfer.recipient_id,
        recipient_name=target_user.name,
        recipient_staff_id=staff_badge_id,
        created_at=new_transfer.created_at,
        sender_balance=updated_sender_bal,
        recipient_balance=updated_recip_bal,
        is_idempotent_replay=False,
    )


@router.get(
    "/points-history",
    response_model=PartnerPointsHistoryResponse,
    status_code=status.HTTP_200_OK,
    summary="Get partner paginated points history",
)
@router.get(
    "/history",
    response_model=PartnerPointsHistoryResponse,
    status_code=status.HTTP_200_OK,
    include_in_schema=False,
)
def get_partner_history(
    page: int = Query(default=1, ge=1, description="Page number (1-based)"),
    page_size: int = Query(default=20, ge=1, le=100, description="Page size (max 100)"),
    current_partner: User = Depends(require_partner),
    db: Session = Depends(get_db),
) -> PartnerPointsHistoryResponse:
    """
    Returns paginated points transaction history for the authenticated partner.
    Includes:
    - QR-based point earnings (PointTransaction)
    - Legacy redeemed QR codes (fallback compatibility)
    - Outbound transfer deductions to staff members (PointTransfer)
    - Inbound transfers received, if applicable (PointTransfer)

    Guarantees:
    - Strict partner data isolation: Partner only sees their own transactions.
    - 100% mathematical consistency with net partner points balance.
    - Deterministic newest-first sort (created_at DESC, id DESC).
    """
    return get_partner_points_history(
        db,
        user_id=current_partner.id,
        page=page,
        page_size=page_size,
    )
