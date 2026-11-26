from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.security import require_staff_or_admin
from app.db.session import get_db
from app.models import Notification, Order, PartnerProfile, User
from app.schemas.notifications import NotificationResponse, NotificationsListResponse

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


def _to_response(n: Notification) -> NotificationResponse:
    order_number = n.order.order_number if n.order else None
    partner_name = None
    if n.order and n.order.partner:
        profile = getattr(n.order.partner, "partner_profile", None)
        partner_name = profile.business_name if profile else n.order.partner.name

    return NotificationResponse(
        id=n.id,
        type=n.type,
        title=n.title,
        body=n.body,
        order_id=n.order_id,
        order_number=order_number,
        partner_name=partner_name,
        is_read=n.is_read,
        created_at=n.created_at,
    )


@router.get("", response_model=NotificationsListResponse)
def get_my_notifications(
    is_read: Optional[bool] = Query(default=None, description="Filter by read status"),
    current_user: User = Depends(require_staff_or_admin),
    db: Session = Depends(get_db),
) -> NotificationsListResponse:
    """Returns notifications for the current authenticated Staff or Admin user."""
    query = (
        select(Notification)
        .options(
            selectinload(Notification.order).selectinload(Order.partner).selectinload(User.partner_profile),
        )
        .where(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )

    if is_read is not None:
        query = query.where(Notification.is_read == is_read)

    notifications = db.scalars(query).all()

    unread_count = db.scalar(
        select(func.count(Notification.id)).where(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
    ) or 0

    return NotificationsListResponse(
        notifications=[_to_response(n) for n in notifications],
        unread_count=unread_count,
    )


@router.post("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_as_read(
    notification_id: int,
    current_user: User = Depends(require_staff_or_admin),
    db: Session = Depends(get_db),
) -> NotificationResponse:
    """Marks a single notification as read."""
    notification = db.scalar(
        select(Notification)
        .options(
            selectinload(Notification.order).selectinload(Order.partner).selectinload(User.partner_profile),
        )
        .where(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
    )
    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found",
        )

    notification.is_read = True
    db.commit()
    db.refresh(notification)
    return _to_response(notification)


@router.post("/read-all", response_model=dict[str, str])
def mark_all_notifications_as_read(
    current_user: User = Depends(require_staff_or_admin),
    db: Session = Depends(get_db),
) -> dict[str, str]:
    """Marks all unread notifications for the current user as read."""
    unread_notifications = db.scalars(
        select(Notification).where(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
    ).all()

    for n in unread_notifications:
        n.is_read = True

    db.commit()
    return {"message": "All notifications marked as read"}
