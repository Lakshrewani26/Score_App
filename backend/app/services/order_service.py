from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Order, OrderStatusHistory, StaffPartnerAssignment, User


def validate_order_status_transition(
    old_status: str,
    target_status: str,
    actor_role: str = "staff",
) -> None:
    """
    Validates state machine transitions for order fulfillment:
    - approved_processing -> dispatched
    - dispatched -> delivered

    Rejects:
    - pending_approval -> dispatched or delivered (orders must be approved first)
    - approved_processing -> delivered (cannot bypass dispatched stage)
    - Terminal states (delivered, rejected, cancelled) cannot be modified
    - Any invalid or unsupported status
    """
    target = target_status.strip().lower() if target_status else ""

    if target not in ("dispatched", "delivered"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported status '{target_status}'. Target status can only be 'dispatched' or 'delivered'.",
        )

    if old_status == "pending_approval":
        if actor_role == "admin":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Order is pending Staff approval. Admin cannot bypass initial approval.",
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Order is pending approval. Order must be approved before it can be dispatched.",
            )
    elif old_status == "delivered":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Order is already delivered and cannot be modified.",
        )
    elif old_status == "rejected":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Order has been rejected and cannot be modified.",
        )
    elif old_status == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Order has been cancelled and cannot be modified.",
        )
    elif old_status == "approved_processing":
        if target != "dispatched":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Order in 'approved_processing' status can only transition to 'dispatched'.",
            )
    elif old_status == "dispatched":
        if target != "delivered":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Order in 'dispatched' status can only transition to 'delivered'.",
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status transition from '{old_status}' to '{target_status}'.",
        )


def verify_staff_partner_assignment(
    db: Session,
    staff_id: int,
    partner_id: int,
) -> bool:
    """
    Verifies that the Staff member is actively assigned to the target Partner.
    Raises 403 Forbidden if not assigned.
    """
    is_assigned = db.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.staff_id == staff_id,
            StaffPartnerAssignment.partner_id == partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    if not is_assigned:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: You are not assigned to this partner's account.",
        )
    return True


def apply_order_status_transition(
    db: Session,
    order: Order,
    target_status: str,
    user: User,
    remarks: Optional[str] = None,
) -> OrderStatusHistory:
    """
    Atomically updates the order status and appends an OrderStatusHistory audit entry.
    Validates state transitions before persisting.
    """
    target = target_status.strip().lower() if target_status else ""
    old_status = order.status

    validate_order_status_transition(old_status, target, actor_role=user.role)

    order.status = target
    clean_remarks = remarks.strip() if remarks and remarks.strip() else None

    history_entry = OrderStatusHistory(
        order_id=order.id,
        old_status=old_status,
        new_status=target,
        changed_by=user.id,
        changed_at=datetime.now(timezone.utc),
        remarks=clean_remarks,
    )
    db.add(history_entry)

    if hasattr(order, "status_history") and order.status_history is not None:
        order.status_history.append(history_entry)

    db.commit()
    db.expire_all()

    return history_entry
