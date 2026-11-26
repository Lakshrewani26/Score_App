from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.models import (
    CustomerProfile,
    Notification,
    Order,
    OrderItem,
    OrderStatusHistory,
    PartnerProfile,
    Product,
    ProductCategory,
    StaffPartnerAssignment,
    StaffProfile,
    User,
)
from app.services.notification_service import create_order_notifications


def _create_user(db: Session, *, name: str, mobile: str, role: str) -> User:
    user = User(
        name=name,
        mobile=mobile,
        role=role,
        is_active=True,
        password_hash=hash_password("SecurePass123!"),
    )
    db.add(user)
    db.flush()
    return user


def _auth(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_order_creation_notifies_staff_and_admin(client: TestClient, db_session: Session) -> None:
    # 1. Setup Admin
    admin = _create_user(db_session, name="Admin Notif", mobile="9700000001", role="admin")

    # 2. Setup 2 Staff members
    staff1 = _create_user(db_session, name="Staff Assigned 1", mobile="9700000002", role="staff")
    db_session.add(StaffProfile(user_id=staff1.id, staff_id="STF-N-01"))
    staff2 = _create_user(db_session, name="Staff Assigned 2", mobile="9700000003", role="staff")
    db_session.add(StaffProfile(user_id=staff2.id, staff_id="STF-N-02"))
    staff_unrelated = _create_user(db_session, name="Staff Other", mobile="9700000004", role="staff")
    db_session.add(StaffProfile(user_id=staff_unrelated.id, staff_id="STF-N-03"))

    # 3. Setup Partner
    partner = _create_user(db_session, name="Partner Buyer", mobile="9700000005", role="partner")
    db_session.add(PartnerProfile(user_id=partner.id, business_name="Buyer Enterprise", business_address="Delhi"))
    db_session.commit()

    # 4. Assign staff1 and staff2 to partner (M2M)
    db_session.add_all([
        StaffPartnerAssignment(staff_id=staff1.id, partner_id=partner.id, is_active=True),
        StaffPartnerAssignment(staff_id=staff2.id, partner_id=partner.id, is_active=True),
    ])
    db_session.commit()

    # 5. Create an order
    order = Order(
        order_number="ORD-TEST-NOTIF-01",
        partner_id=partner.id,
        status="pending_approval",
        final_total=5000.00,
    )
    db_session.add(order)
    db_session.commit()
    db_session.refresh(order)

    # 6. Trigger notifications
    created = create_order_notifications(db_session, order)
    assert len(created) == 3  # staff1, staff2, and admin

    # 7. Check staff 1 notifications
    res1 = client.get("/api/v1/notifications", headers=_auth(staff1))
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["unread_count"] == 1
    assert len(data1["notifications"]) == 1
    assert data1["notifications"][0]["order_number"] == "ORD-TEST-NOTIF-01"
    assert "Buyer Enterprise" in data1["notifications"][0]["body"] or "Buyer Enterprise" in (data1["notifications"][0]["partner_name"] or "")

    # 8. Check staff 2 notifications
    res2 = client.get("/api/v1/notifications", headers=_auth(staff2))
    assert res2.status_code == 200
    assert res2.json()["unread_count"] == 1

    # 9. Check admin notifications
    res_admin = client.get("/api/v1/notifications", headers=_auth(admin))
    assert res_admin.status_code == 200
    assert res_admin.json()["unread_count"] >= 1

    # 10. Check unrelated staff receives NO notification
    res_other = client.get("/api/v1/notifications", headers=_auth(staff_unrelated))
    assert res_other.status_code == 200
    assert res_other.json()["unread_count"] == 0

    # 11. Deduplication check: calling create_order_notifications again does NOT create duplicates
    created_again = create_order_notifications(db_session, order)
    assert len(created_again) == 0


def test_mark_notification_as_read(client: TestClient, db_session: Session) -> None:
    staff = _create_user(db_session, name="Staff Reader", mobile="9700000011", role="staff")
    db_session.add(StaffProfile(user_id=staff.id, staff_id="STF-N-11"))
    db_session.commit()

    notif = Notification(
        user_id=staff.id,
        type="new_order",
        title="New Order Received",
        body="Order ORD-99999",
        is_read=False,
    )
    db_session.add(notif)
    db_session.commit()
    db_session.refresh(notif)

    headers = _auth(staff)

    # Mark as read
    read_res = client.post(f"/api/v1/notifications/{notif.id}/read", headers=headers)
    assert read_res.status_code == 200
    assert read_res.json()["is_read"] is True

    # Unread count now 0
    list_res = client.get("/api/v1/notifications", headers=headers)
    assert list_res.json()["unread_count"] == 0


def test_customer_and_partner_cannot_access_notifications(client: TestClient, db_session: Session) -> None:
    customer = _create_user(db_session, name="Cust", mobile="9700000021", role="customer")
    partner = _create_user(db_session, name="Part", mobile="9700000022", role="partner")
    db_session.commit()

    # Customer forbidden
    c_res = client.get("/api/v1/notifications", headers=_auth(customer))
    assert c_res.status_code == 403

    # Partner forbidden
    p_res = client.get("/api/v1/notifications", headers=_auth(partner))
    assert p_res.status_code == 403
