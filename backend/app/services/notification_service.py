from __future__ import annotations

import logging
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Notification, Order, PartnerProfile, StaffPartnerAssignment, User

logger = logging.getLogger(__name__)


def create_order_notifications(db: Session, order: Order) -> list[Notification]:
    """Create in-app notifications for assigned Staff members and Admin users

    when a new order is received.
    - Assigned Staff: All active staff members currently assigned to the order's partner (M2M).
    - Admins: All active admin users.
    - Prevents duplicate notifications for the same user + order.
    """
    # 1. Fetch partner business name or fallback to user name
    partner_profile = db.scalar(
        select(PartnerProfile).where(PartnerProfile.user_id == order.partner_id)
    )
    partner_user = db.get(User, order.partner_id)
    partner_name = (
        (partner_profile.business_name if partner_profile else None)
        or (partner_user.name if partner_user else f"Partner #{order.partner_id}")
    )

    # 2. Find all active staff members assigned to this partner (M2M)
    assigned_staff_ids = db.scalars(
        select(StaffPartnerAssignment.staff_id).where(
            StaffPartnerAssignment.partner_id == order.partner_id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    ).all()

    # 3. Find all active admin users
    admin_ids = db.scalars(
        select(User.id).where(
            User.role == "admin",
            User.is_active.is_(True),
        )
    ).all()

    # Combine recipient IDs (set to remove any potential overlap)
    recipient_ids = set(assigned_staff_ids) | set(admin_ids)

    # 4. Check existing notifications for this order to prevent duplicates
    notifications_created = []
    try:
        existing_notified_user_ids = set(
            db.scalars(
                select(Notification.user_id).where(
                    Notification.order_id == order.id,
                )
            ).all()
        )

        title = "New Order Received"
        body = (
            f"Order: {order.order_number}\n"
            f"Partner: {partner_name}\n"
            f"Items: {len(order.items) if order.items else 0} | Total: ₹{order.final_total or '0.00'}"
        )

        for user_id in recipient_ids:
            if user_id in existing_notified_user_ids:
                continue

            notification = Notification(
                user_id=user_id,
                type="new_order",
                title=title,
                body=body,
                order_id=order.id,
                is_read=False,
            )
            db.add(notification)
            notifications_created.append(notification)

        if notifications_created:
            db.commit()
    except Exception as exc:
        db.rollback()
        logger.warning("Could not dispatch order notifications: %s", exc)

    return notifications_created
