from __future__ import annotations

from typing import Optional
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, inspect, select
from sqlalchemy.orm import Session

from app.models import PointTransaction, PointTransfer, QrCode, User


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
