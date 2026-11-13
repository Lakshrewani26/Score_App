from __future__ import annotations

from datetime import datetime, timezone
import math
from typing import Optional

from fastapi import HTTPException, status
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, selectinload

from app.models import (
    PartnerProfile,
    PaymentStatusHistory,
    StaffPaymentRecord,
    User,
)
from app.schemas.staff import (
    PaymentReviewDetail,
    StaffPaymentListResponse,
    StaffPaymentResponse,
)


def validate_payment_status_transition(
    old_status: str,
    target_status: str,
) -> None:
    """
    Validates state machine transitions for payment review:
    - recorded -> approved
    - recorded -> rejected
    - recorded -> voided

    Terminal statuses (approved, rejected, voided) cannot be modified.
    """
    target = target_status.strip().lower() if target_status else ""

    if target not in ("approved", "rejected", "voided"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported status '{target_status}'. Target status must be 'approved', 'rejected', or 'voided'.",
        )

    if old_status != "recorded":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Payment in '{old_status}' status cannot be transitioned. Only payments awaiting review ('recorded') may be updated.",
        )


def verify_staff_payment_access(payment: StaffPaymentRecord, user: User) -> None:
    """
    Enforces authorization:
    - Staff members may only view or review payments assigned directly to their user ID.
    - Admins are authorized across payment records according to admin policy.
    - Other roles are rejected.
    """
    if user.role == "staff":
        if payment.staff_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: You are not assigned to this payment record.",
            )
    elif user.role == "admin":
        return
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff or Admin privileges required",
        )


def build_payment_response(payment: StaffPaymentRecord) -> StaffPaymentResponse:
    """
    Serializes a StaffPaymentRecord with partner, recorder, and review audit details.
    """
    partner_name: Optional[str] = None
    business_name: Optional[str] = None
    partner_mobile: Optional[str] = None

    if payment.partner:
        business_name = payment.partner.business_name
        if payment.partner.user:
            partner_name = payment.partner.user.name
            partner_mobile = payment.partner.user.mobile

    recorded_by_name: Optional[str] = payment.actor.name if payment.actor else None

    raw_history = payment.status_history or []
    sorted_history = sorted(
        raw_history,
        key=lambda h: (h.changed_at or datetime.min.replace(tzinfo=timezone.utc), h.id or 0),
        reverse=True,
    )

    history_items: list[PaymentReviewDetail] = []
    for h in sorted_history:
        history_items.append(
            PaymentReviewDetail(
                changed_by=h.changed_by,
                changed_by_name=h.actor.name if h.actor else None,
                changed_at=h.changed_at,
                old_status=h.old_status,
                new_status=h.new_status,
                remarks=h.remarks,
            )
        )

    latest_review = history_items[0] if history_items else None

    return StaffPaymentResponse(
        id=payment.id,
        staff_id=payment.staff_id,
        partner_id=payment.partner_id,
        partner_name=partner_name,
        business_name=business_name,
        partner_mobile=partner_mobile,
        amount=payment.amount,
        payment_method=payment.payment_method,
        reference_number=payment.reference_number,
        status=payment.status,
        recorded_by=payment.recorded_by,
        recorded_by_name=recorded_by_name,
        recorded_at=payment.recorded_at,
        notes=payment.notes,
        latest_review=latest_review,
        status_history=history_items,
    )


def apply_payment_status_transition(
    db: Session,
    payment: StaffPaymentRecord,
    target_status: str,
    user: User,
    remarks: Optional[str] = None,
) -> PaymentStatusHistory:
    """
    Atomically updates payment status and records an audit entry in PaymentStatusHistory.
    """
    target = target_status.strip().lower() if target_status else ""
    validate_payment_status_transition(payment.status, target)

    clean_remarks = remarks.strip() if remarks and remarks.strip() else None
    if target == "rejected" and not clean_remarks:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rejection reason is required",
        )

    old_status = payment.status
    payment.status = target

    history_entry = PaymentStatusHistory(
        payment_record_id=payment.id,
        old_status=old_status,
        new_status=target,
        changed_by=user.id,
        changed_at=datetime.now(timezone.utc),
        remarks=clean_remarks,
    )
    db.add(history_entry)

    if hasattr(payment, "status_history") and payment.status_history is not None:
        payment.status_history.insert(0, history_entry)

    db.commit()
    db.refresh(payment)

    return history_entry
