from __future__ import annotations

from datetime import datetime, timezone
import math
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, inspect, select
from sqlalchemy.orm import Session, selectinload

from app.models import PointTransaction, PointTransfer, QrCode, User
from app.schemas.customer import (
    CustomerPointHistoryItem,
    CustomerPointsHistoryResponse,
)


def _get_existing_tables(db: Session) -> set[str]:
    """
    Safely inspects existing table names in the current database connection.
    Guarantees compatibility when tests configure isolated/partial table fixtures.
    """
    try:
        bind = db.get_bind()
        return set(inspect(bind).get_table_names())
    except Exception:
        return {"point_transactions", "point_transfers", "qr_codes", "users"}


class PointsBalanceSummary(BaseModel):
    """
    Unified points balance summary model for any user role.
    All point calculations use integer arithmetic.
    """
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    role: Optional[str] = None
    points_earned: int = Field(
        default=0,
        description="Points directly earned via point_transactions (QR scans/applicable credits)",
    )
    transfers_received: int = Field(
        default=0,
        description="Points received via point_transfers ledger",
    )
    transfers_sent: int = Field(
        default=0,
        description="Points sent via point_transfers ledger",
    )
    points_spent: int = Field(
        default=0,
        description="Total points deducted/spent (transfers sent + supported deductions)",
    )
    current_balance: int = Field(
        default=0,
        description="Net current points balance (earned + received - spent)",
    )


def get_user_points_balance(
    db: Session,
    user_id: int,
    role: Optional[str] = None,
) -> PointsBalanceSummary:
    """
    Calculates the unified points balance for a given user.

    Accounts for:
    - Points earned from existing point_transactions (QR scans/applicable credits)
    - Fallback for redeemed QrCode records unlinked from point_transactions
    - Points sent through point_transfers (reduces balance)
    - Points received through point_transfers (increases balance)
    - Any supported deduction records

    Formula:
    credits = points_earned + transfers_received
    debits = transfers_sent
    current_balance = credits - debits
    """
    if role is None:
        user_role = db.scalar(select(User.role).where(User.id == user_id))
        role = user_role.lower() if user_role else ""
    else:
        role = role.lower()

    existing_tables = _get_existing_tables(db)
    has_pt = "point_transactions" in existing_tables
    has_ptr = "point_transfers" in existing_tables
    has_qc = "qr_codes" in existing_tables

    # 1. Points earned from PointTransaction
    pts_earned = 0
    if has_pt:
        pts_earned = db.scalar(
            select(func.coalesce(func.sum(PointTransaction.points_awarded), 0)).where(
                PointTransaction.user_id == user_id
            )
        ) or 0

    # Fallback for any legacy/manually redeemed QrCodes not recorded in PointTransaction
    qr_fallback = 0
    if has_qc:
        if has_pt:
            qr_fallback = db.scalar(
                select(func.coalesce(func.sum(QrCode.points_awarded), 0)).where(
                    QrCode.redeemed_by == user_id,
                    QrCode.status == "redeemed",
                    ~QrCode.id.in_(select(PointTransaction.qr_code_id)),
                )
            ) or 0
        else:
            qr_fallback = db.scalar(
                select(func.coalesce(func.sum(QrCode.points_awarded), 0)).where(
                    QrCode.redeemed_by == user_id,
                    QrCode.status == "redeemed",
                )
            ) or 0
    total_earned = int(pts_earned) + int(qr_fallback)

    # 2. Points sent via PointTransfer (debits)
    transfers_sent = 0
    if has_ptr:
        pts_sent = db.scalar(
            select(func.coalesce(func.sum(PointTransfer.amount), 0)).where(
                PointTransfer.sender_id == user_id
            )
        ) or 0
        transfers_sent = int(pts_sent)

    # 3. Points received via PointTransfer (credits)
    transfers_received = 0
    if has_ptr:
        pts_recv = db.scalar(
            select(func.coalesce(func.sum(PointTransfer.amount), 0)).where(
                PointTransfer.recipient_id == user_id
            )
        ) or 0
        transfers_received = int(pts_recv)

    # 4. Role-specific rules:
    # Staff cannot scan QR codes for loyalty points; staff balance is transfer-based
    if role == "staff":
        points_earned_val = 0
    else:
        points_earned_val = total_earned

    points_spent = transfers_sent
    current_balance = points_earned_val + transfers_received - points_spent

    return PointsBalanceSummary(
        user_id=user_id,
        role=role,
        points_earned=points_earned_val,
        transfers_received=transfers_received,
        transfers_sent=transfers_sent,
        points_spent=points_spent,
        current_balance=current_balance,
    )


def get_users_points_balances(
    db: Session,
    user_ids: list[int],
) -> dict[int, PointsBalanceSummary]:
    """
    Batch calculates unified points balances for a collection of user IDs,
    avoiding N+1 queries.
    """
    if not user_ids:
        return {}

    user_roles = dict(
        db.execute(
            select(User.id, User.role).where(User.id.in_(user_ids))
        ).all()
    )

    existing_tables = _get_existing_tables(db)
    has_pt = "point_transactions" in existing_tables
    has_ptr = "point_transfers" in existing_tables
    has_qc = "qr_codes" in existing_tables

    # Grouped earned points
    earned_by_user = {}
    if has_pt:
        earned_stmt = (
            select(PointTransaction.user_id, func.coalesce(func.sum(PointTransaction.points_awarded), 0))
            .where(PointTransaction.user_id.in_(user_ids))
            .group_by(PointTransaction.user_id)
        )
        earned_by_user = dict(db.execute(earned_stmt).all())

    # Fallback for unlinked QrCodes
    fallback_by_user = {}
    if has_qc:
        if has_pt:
            fallback_stmt = (
                select(QrCode.redeemed_by, func.coalesce(func.sum(QrCode.points_awarded), 0))
                .where(
                    QrCode.redeemed_by.in_(user_ids),
                    QrCode.status == "redeemed",
                    ~QrCode.id.in_(select(PointTransaction.qr_code_id)),
                )
                .group_by(QrCode.redeemed_by)
            )
        else:
            fallback_stmt = (
                select(QrCode.redeemed_by, func.coalesce(func.sum(QrCode.points_awarded), 0))
                .where(
                    QrCode.redeemed_by.in_(user_ids),
                    QrCode.status == "redeemed",
                )
                .group_by(QrCode.redeemed_by)
            )
        fallback_by_user = dict(db.execute(fallback_stmt).all())

    # Grouped transfers sent
    sent_by_user = {}
    if has_ptr:
        sent_stmt = (
            select(PointTransfer.sender_id, func.coalesce(func.sum(PointTransfer.amount), 0))
            .where(PointTransfer.sender_id.in_(user_ids))
            .group_by(PointTransfer.sender_id)
        )
        sent_by_user = dict(db.execute(sent_stmt).all())

    # Grouped transfers received
    recv_by_user = {}
    if has_ptr:
        recv_stmt = (
            select(PointTransfer.recipient_id, func.coalesce(func.sum(PointTransfer.amount), 0))
            .where(PointTransfer.recipient_id.in_(user_ids))
            .group_by(PointTransfer.recipient_id)
        )
        recv_by_user = dict(db.execute(recv_stmt).all())

    results: dict[int, PointsBalanceSummary] = {}
    for uid in user_ids:
        role = (user_roles.get(uid) or "").lower()
        pts_earned = int(earned_by_user.get(uid, 0)) + int(fallback_by_user.get(uid, 0))
        if role == "staff":
            pts_earned = 0
        t_sent = int(sent_by_user.get(uid, 0))
        t_recv = int(recv_by_user.get(uid, 0))
        spent = t_sent
        bal = pts_earned + t_recv - spent

        results[uid] = PointsBalanceSummary(
            user_id=uid,
            role=role,
            points_earned=pts_earned,
            transfers_received=t_recv,
            transfers_sent=t_sent,
            points_spent=spent,
            current_balance=bal,
        )

    return results


def calculate_user_balance(
    db: Session,
    user_id: int,
    role: Optional[str] = None,
) -> int:
    """
    Convenience helper returning just the integer balance for a user.
    """
    return get_user_points_balance(db, user_id, role=role).current_balance


def _normalize_dt(dt: Optional[datetime]) -> datetime:
    """Ensures datetime is timezone-aware UTC for safe comparisons."""
    if dt is None:
        return datetime.now(timezone.utc)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def get_customer_points_history(
    db: Session,
    user_id: int,
    page: int = 1,
    page_size: int = 20,
) -> CustomerPointsHistoryResponse:
    """
    Retrieves the complete, unified, paginated points history for a Customer.
    Includes:
    - Product QR scans (PointTransaction)
    - Legacy redeemed QR codes (QrCode without PointTransaction)
    - Deductions / transfers sent (PointTransfer)
    - Inbound transfers received, if applicable (PointTransfer)

    Guarantees:
    - User isolation: only returns records associated with user_id.
    - Consistency: points in history directly sum to PointsBalanceSummary.
    - Deterministic ordering: sorted newest first (created_at DESC), with unique ID tie-breaker.
    - Safe table inspection for compatibility with isolated test fixtures.
    """
    if page < 1:
        page = 1
    if page_size < 1:
        page_size = 20
    if page_size > 100:
        page_size = 100

    existing_tables = _get_existing_tables(db)
    has_pt = "point_transactions" in existing_tables
    has_ptr = "point_transfers" in existing_tables
    has_qc = "qr_codes" in existing_tables

    all_items: list[CustomerPointHistoryItem] = []

    # 1. Product QR earnings from PointTransaction
    if has_pt:
        txs = db.scalars(
            select(PointTransaction)
            .options(selectinload(PointTransaction.points_rule))
            .where(PointTransaction.user_id == user_id)
        ).all()
        for tx in txs:
            rule_name = tx.points_rule.rule_name if tx.points_rule else None
            title = f"Points Earned ({rule_name})" if rule_name else "Points Earned (Product QR)"
            all_items.append(
                CustomerPointHistoryItem(
                    id=f"pt-{tx.id}",
                    transaction_type=tx.transaction_type or "qr_scan",
                    direction="credit",
                    points=tx.points_awarded,
                    amount=tx.points_awarded,
                    title=title,
                    description=f"Product QR scan: {tx.qr_token}",
                    reference_id=tx.qr_token,
                    created_at=_normalize_dt(tx.created_at),
                )
            )

    # 2. Legacy / unlinked redeemed QrCodes (fallback credits)
    if has_qc:
        if has_pt:
            legacy_qrs = db.scalars(
                select(QrCode).where(
                    QrCode.redeemed_by == user_id,
                    QrCode.status == "redeemed",
                    ~QrCode.id.in_(select(PointTransaction.qr_code_id)),
                )
            ).all()
        else:
            legacy_qrs = db.scalars(
                select(QrCode).where(
                    QrCode.redeemed_by == user_id,
                    QrCode.status == "redeemed",
                )
            ).all()

        for qr in legacy_qrs:
            pts = qr.points_awarded or 0
            dt = qr.redeemed_at or qr.created_at
            all_items.append(
                CustomerPointHistoryItem(
                    id=f"qc-{qr.id}",
                    transaction_type="legacy_qr_scan",
                    direction="credit",
                    points=pts,
                    amount=pts,
                    title="Points Earned (Product QR)",
                    description=f"Product QR scan: {qr.token}",
                    reference_id=qr.token,
                    created_at=_normalize_dt(dt),
                )
            )

    # 3. Deductions / transfers sent (PointTransfer)
    if has_ptr:
        sent_transfers = db.scalars(
            select(PointTransfer)
            .options(selectinload(PointTransfer.recipient))
            .where(PointTransfer.sender_id == user_id)
        ).all()
        for tr in sent_transfers:
            recip_name = tr.recipient.name if tr.recipient else "Partner"
            all_items.append(
                CustomerPointHistoryItem(
                    id=f"tr-{tr.id}",
                    transaction_type="transfer_sent",
                    direction="debit",
                    points=-tr.amount,
                    amount=tr.amount,
                    title=f"Points Transferred to {recip_name}",
                    description=tr.remarks or f"Transferred {tr.amount} points to {recip_name}",
                    reference_id=tr.idempotency_key,
                    recipient_name=recip_name,
                    created_at=_normalize_dt(tr.created_at),
                )
            )

    # 4. Inbound transfers received (if any exist)
    if has_ptr:
        recv_transfers = db.scalars(
            select(PointTransfer)
            .options(selectinload(PointTransfer.sender))
            .where(PointTransfer.recipient_id == user_id)
        ).all()
        for tr in recv_transfers:
            snd_name = tr.sender.name if tr.sender else "User"
            all_items.append(
                CustomerPointHistoryItem(
                    id=f"tr-recv-{tr.id}",
                    transaction_type="transfer_received",
                    direction="credit",
                    points=tr.amount,
                    amount=tr.amount,
                    title=f"Points Received from {snd_name}",
                    description=tr.remarks or f"Received {tr.amount} points from {snd_name}",
                    reference_id=tr.idempotency_key,
                    sender_name=snd_name,
                    created_at=_normalize_dt(tr.created_at),
                )
            )

    # Deterministic sorting: newest first, tie-break by deterministic id
    all_items.sort(
        key=lambda it: (_normalize_dt(it.created_at), it.id),
        reverse=True,
    )

    total = len(all_items)
    total_pages = math.ceil(total / page_size) if total > 0 else 0
    start = (page - 1) * page_size
    end = start + page_size
    page_items = all_items[start:end]

    has_next = page < total_pages
    has_prev = page > 1 and page <= total_pages + 1

    return CustomerPointsHistoryResponse(
        items=page_items,
        total=total,
        page=page,
        page_size=page_size,
        total_pages=total_pages,
        has_next=has_next,
        has_prev=has_prev,
    )
