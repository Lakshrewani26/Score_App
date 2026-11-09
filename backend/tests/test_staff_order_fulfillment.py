from __future__ import annotations

from collections.abc import Generator
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import (
    CustomerProfile,
    Order,
    OrderItem,
    OrderStatusHistory,
    PartnerProfile,
    Product,
    ProductCategory,
    QrBatch,
    QrCode,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    User,
)


@pytest.fixture
def test_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(
        bind=engine,
        tables=[
            User.__table__,
            CustomerProfile.__table__,
            PartnerProfile.__table__,
            StaffProfile.__table__,
            ProductCategory.__table__,
            Product.__table__,
            Order.__table__,
            OrderItem.__table__,
            OrderStatusHistory.__table__,
            StaffPartnerAssignment.__table__,
            StaffPaymentRecord.__table__,
            QrBatch.__table__,
            QrCode.__table__,
        ],
    )
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine) -> Generator[Session, None, None]:
    with Session(test_engine) as session:
        yield session


@pytest.fixture
def client(test_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


def _create_user(db: Session, *, name: str, mobile: str, role: str) -> User:
    user = User(
        mobile=mobile,
        name=name,
        role=role,
        is_active=True,
        password_hash=hash_password("Secret123"),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_staff(db: Session, *, name: str, mobile: str, staff_code: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="staff")
    db.add(StaffProfile(user_id=user.id, staff_id=staff_code))
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="staff", mobile=user.mobile)
    return user, token


def _create_partner(db: Session, *, name: str, mobile: str, business: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="partner")
    db.add(
        PartnerProfile(
            user_id=user.id,
            business_name=business,
            business_address="123 Industrial Area, Sector 5",
            partner_code=f"PRT-{mobile[-4:]}",
            discount_percentage=Decimal("5.00"),
        )
    )
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="partner", mobile=user.mobile)
    return user, token


def _create_customer(db: Session, *, name: str, mobile: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="customer")
    db.add(CustomerProfile(user_id=user.id, city="Delhi", state="Delhi"))
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="customer", mobile=user.mobile)
    return user, token


def _get_or_create_product(db: Session, suffix: str = "") -> Product:
    cat = db.query(ProductCategory).filter_by(name="Fulfillment Parts").first()
    if not cat:
        cat = ProductCategory(name="Fulfillment Parts", description="Test Category")
        db.add(cat)
        db.flush()
    code = f"PRD-FULFILL-{suffix or 'DEFAULT'}"
    prod = db.query(Product).filter_by(product_code=code).first()
    if not prod:
        prod = Product(
            category_id=cat.id,
            product_code=code,
            name=f"Fulfillment Clutch Plate {suffix}",
            vehicle_type="2-Wheeler",
            price=Decimal("450.00"),
            is_active=True,
        )
        db.add(prod)
        db.commit()
        db.refresh(prod)
    return prod


def _create_order(
    db: Session,
    partner: User,
    *,
    status: str = "approved_processing",
    order_number: str = "ORD-FL-001",
) -> Order:
    prod = _get_or_create_product(db, order_number)
    order = Order(
        order_number=order_number,
        partner_id=partner.id,
        status=status,
        notes="Fulfillment test order",
    )
    db.add(order)
    db.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=prod.id,
        quantity=3,
        unit_price=prod.price,
    )
    db.add(item)

    history = OrderStatusHistory(
        order_id=order.id,
        old_status=None,
        new_status=status,
        changed_by=partner.id,
        remarks=f"Initial order creation in {status} state",
    )
    db.add(history)
    db.commit()
    db.refresh(order)
    return order


# =========================================================================
# 1. Staff Order Progression Tests (Dispatched and Delivered)
# =========================================================================

def test_staff_can_mark_approved_order_as_dispatched(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Suresh Staff", mobile="9800000001", staff_code="STF-FUL-01")
    partner, _ = _create_partner(db_session, name="Ramesh Auto", mobile="9800000002", business="Ramesh Spares")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order = _create_order(db_session, partner, status="approved_processing", order_number="ORD-DISPATCH-01")

    # Staff transitions order to dispatched
    res = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched", "remarks": "Handed over to DTDC courier #TRK1234"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "dispatched"
    assert data["id"] == order.id

    # Verify status history in response
    assert "status_history" in data
    assert len(data["status_history"]) >= 2
    last_hist = data["status_history"][-1]
    assert last_hist["old_status"] == "approved_processing"
    assert last_hist["new_status"] == "dispatched"
    assert last_hist["changed_by"] == staff.id
    assert last_hist["changed_by_name"] == "Suresh Staff"
    assert last_hist["remarks"] == "Handed over to DTDC courier #TRK1234"

    # Verify DB persistence directly
    db_session.expire_all()
    db_order = db_session.get(Order, order.id)
    assert db_order.status == "dispatched"

    db_hist = (
        db_session.query(OrderStatusHistory)
        .filter_by(order_id=order.id, new_status="dispatched")
        .first()
    )
    assert db_hist is not None
    assert db_hist.old_status == "approved_processing"
    assert db_hist.changed_by == staff.id
    assert db_hist.remarks == "Handed over to DTDC courier #TRK1234"


def test_staff_can_mark_dispatched_order_as_delivered(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Kavita Staff", mobile="9800000003", staff_code="STF-FUL-02")
    partner, _ = _create_partner(db_session, name="Modern Garage", mobile="9800000004", business="Modern Garage LLC")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order = _create_order(db_session, partner, status="dispatched", order_number="ORD-DELIVER-01")

    # Staff transitions order to delivered
    res = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "delivered", "remarks": "Delivered and verified by shop manager"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "delivered"
    assert data["id"] == order.id

    # Verify status history
    last_hist = data["status_history"][-1]
    assert last_hist["old_status"] == "dispatched"
    assert last_hist["new_status"] == "delivered"
    assert last_hist["changed_by"] == staff.id
    assert last_hist["changed_by_name"] == "Kavita Staff"
    assert last_hist["remarks"] == "Delivered and verified by shop manager"

    # Verify DB persistence
    db_session.expire_all()
    db_order = db_session.get(Order, order.id)
    assert db_order.status == "delivered"


# =========================================================================
# 2. State Machine Enforcement Tests (Invalid Transitions Rejected)
# =========================================================================

def test_staff_cannot_skip_processing_directly_to_delivered(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Skip", mobile="9800000005", staff_code="STF-FUL-03")
    partner, _ = _create_partner(db_session, name="Apex Spares", mobile="9800000006", business="Apex Auto")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order = _create_order(db_session, partner, status="approved_processing", order_number="ORD-SKIP-01")

    # Attempt premature jump: approved_processing -> delivered
    res = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "delivered", "remarks": "Trying to bypass dispatch stage"},
    )
    assert res.status_code == 400
    assert "dispatched" in res.json()["detail"].lower()

    # DB remains unchanged
    db_session.expire_all()
    assert db_session.get(Order, order.id).status == "approved_processing"


def test_staff_cannot_dispatch_or_deliver_pending_approval_order(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Pending", mobile="9800000007", staff_code="STF-FUL-04")
    partner, _ = _create_partner(db_session, name="Beta Spares", mobile="9800000008", business="Beta Motors")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order = _create_order(db_session, partner, status="pending_approval", order_number="ORD-PEND-01")

    # 1. Attempt to dispatch pending order without approval
    res_dispatch = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched", "remarks": "Dispatch without approval"},
    )
    assert res_dispatch.status_code == 400
    assert "pending approval" in res_dispatch.json()["detail"].lower()

    # 2. Attempt to deliver pending order without approval
    res_deliver = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "delivered", "remarks": "Deliver without approval"},
    )
    assert res_deliver.status_code == 400
    assert "pending approval" in res_deliver.json()["detail"].lower()

    # DB remains pending_approval
    db_session.expire_all()
    assert db_session.get(Order, order.id).status == "pending_approval"


def test_staff_cannot_modify_delivered_terminal_orders(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Term1", mobile="9800000009", staff_code="STF-FUL-05")
    partner, _ = _create_partner(db_session, name="Gamma Spares", mobile="9800000010", business="Gamma Spares")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order = _create_order(db_session, partner, status="delivered", order_number="ORD-TERM-DEL")

    # Attempt to transition already delivered order
    res = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched", "remarks": "Attempt revert to dispatched"},
    )
    assert res.status_code == 400
    assert "already delivered" in res.json()["detail"].lower()

    res_deliver = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "delivered", "remarks": "Re-delivering"},
    )
    assert res_deliver.status_code == 400
    assert "already delivered" in res_deliver.json()["detail"].lower()

    db_session.expire_all()
    assert db_session.get(Order, order.id).status == "delivered"


def test_staff_cannot_modify_rejected_or_cancelled_orders(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Term2", mobile="9800000011", staff_code="STF-FUL-06")
    partner, _ = _create_partner(db_session, name="Delta Spares", mobile="9800000012", business="Delta Auto")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order_rejected = _create_order(db_session, partner, status="rejected", order_number="ORD-TERM-REJ")
    order_cancelled = _create_order(db_session, partner, status="cancelled", order_number="ORD-TERM-CAN")

    # Rejected order cannot transition
    res_rej = client.patch(
        f"/api/v1/staff/orders/{order_rejected.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched"},
    )
    assert res_rej.status_code == 400
    assert "rejected" in res_rej.json()["detail"].lower()

    # Cancelled order cannot transition
    res_can = client.patch(
        f"/api/v1/staff/orders/{order_cancelled.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched"},
    )
    assert res_can.status_code == 400
    assert "cancelled" in res_can.json()["detail"].lower()


def test_staff_cannot_set_invalid_or_unsupported_statuses(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Arbitrary", mobile="9800000013", staff_code="STF-FUL-07")
    partner, _ = _create_partner(db_session, name="Epsilon Spares", mobile="9800000014", business="Epsilon Auto")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order = _create_order(db_session, partner, status="approved_processing", order_number="ORD-INV-01")

    # 1. Arbitrary / unknown status
    res1 = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "shipped_express"},
    )
    assert res1.status_code == 400
    assert "unsupported status" in res1.json()["detail"].lower()

    # 2. Setting back to approved_processing
    res2 = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "approved_processing"},
    )
    assert res2.status_code == 400
    assert "unsupported status" in res2.json()["detail"].lower()

    # 3. Setting to cancelled
    res3 = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "cancelled"},
    )
    assert res3.status_code == 400
    assert "unsupported status" in res3.json()["detail"].lower()


# =========================================================================
# 3. Staff-Partner Assignment Authorization Tests
# =========================================================================

def test_staff_cannot_update_order_of_unassigned_partner(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Unassigned", mobile="9800000015", staff_code="STF-FUL-08")
    other_partner, _ = _create_partner(db_session, name="Stranger Partner", mobile="9800000016", business="Stranger Auto")
    # Not assigned to staff!

    order = _create_order(db_session, other_partner, status="approved_processing", order_number="ORD-UNASS-01")

    res = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched", "remarks": "Unauthorized attempt"},
    )
    assert res.status_code == 403
    assert "not assigned" in res.json()["detail"].lower()

    # Order status must remain unchanged in DB
    db_session.expire_all()
    assert db_session.get(Order, order.id).status == "approved_processing"


def test_staff_cannot_update_order_when_assignment_is_inactive(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff Inactive", mobile="9800000017", staff_code="STF-FUL-09")
    partner, _ = _create_partner(db_session, name="Ex-Partner", mobile="9800000018", business="Ex Auto")
    # Inactive assignment:
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=False))
    db_session.commit()

    order = _create_order(db_session, partner, status="approved_processing", order_number="ORD-INACT-01")

    res = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched"},
    )
    assert res.status_code == 403
    assert "not assigned" in res.json()["detail"].lower()


# =========================================================================
# 4. Role & Authentication Access Control Tests
# =========================================================================

def test_partner_and_customer_cannot_call_staff_status_endpoint(
    client: TestClient, db_session: Session
) -> None:
    partner, partner_token = _create_partner(db_session, name="Dealer Guy", mobile="9800000019", business="Dealer Shop")
    customer, customer_token = _create_customer(db_session, name="Regular Buyer", mobile="9800000020")

    order = _create_order(db_session, partner, status="approved_processing", order_number="ORD-ROLE-01")

    # 1. Partner cannot call Staff status endpoint
    res_partner = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={"status": "dispatched"},
    )
    assert res_partner.status_code == 403
    assert "staff privileges required" in res_partner.json()["detail"].lower()

    # 2. Customer cannot call Staff status endpoint
    res_customer = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {customer_token}"},
        json={"status": "dispatched"},
    )
    assert res_customer.status_code == 403
    assert "staff privileges required" in res_customer.json()["detail"].lower()

    # 3. Unauthenticated request rejected with 401
    res_unauth = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        json={"status": "dispatched"},
    )
    assert res_unauth.status_code == 401


def test_nonexistent_order_returns_404(
    client: TestClient, db_session: Session
) -> None:
    staff, staff_token = _create_staff(db_session, name="Staff 404", mobile="9800000021", staff_code="STF-FUL-10")

    res = client.patch(
        "/api/v1/staff/orders/999999/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched"},
    )
    assert res.status_code == 404
    assert "order not found" in res.json()["detail"].lower()


# =========================================================================
# 5. Full End-to-End Staff Order Lifecycle & Audit History
# =========================================================================

def test_full_staff_fulfillment_lifecycle_audit_trail(
    client: TestClient, db_session: Session
) -> None:
    """
    Validates complete order lifecycle managed by assigned Staff:
    1. Order created in pending_approval.
    2. Staff approves order -> transitions to approved_processing.
    3. Staff dispatches order -> transitions to dispatched.
    4. Staff delivers order -> transitions to delivered.
    5. Order status history audit trail captures each actor, timestamp, status, and remarks.
    6. All transitions and history records persist in database.
    """
    staff, staff_token = _create_staff(db_session, name="Manoj Kumar", mobile="9800000022", staff_code="STF-FUL-11")
    partner, _ = _create_partner(db_session, name="Vikas Wheels", mobile="9800000023", business="Vikas Wheels Pvt Ltd")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    # Step 1: Partner order placed (pending_approval)
    order = _create_order(db_session, partner, status="pending_approval", order_number="ORD-LIFECYCLE-01")

    # Step 2: Staff approves the order
    res_approve = client.post(
        f"/api/v1/staff/orders/{order.id}/approve",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"remarks": "Verified inventory; order approved for fulfillment"},
    )
    assert res_approve.status_code == 200
    data_approve = res_approve.json()
    assert data_approve["status"] == "approved_processing"
    assert data_approve["approved_by"] == staff.id

    # Step 3: Staff dispatches the order
    res_dispatch = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "dispatched", "remarks": "Dispatched with BlueDart AWB #998877"},
    )
    assert res_dispatch.status_code == 200
    data_dispatch = res_dispatch.json()
    assert data_dispatch["status"] == "dispatched"

    # Step 4: Staff marks order as delivered
    res_deliver = client.patch(
        f"/api/v1/staff/orders/{order.id}/status",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"status": "delivered", "remarks": "Received by store manager Vikas"},
    )
    assert res_deliver.status_code == 200
    data_deliver = res_deliver.json()
    assert data_deliver["status"] == "delivered"

    # Step 5: Check audit history completeness in response
    history = data_deliver["status_history"]
    assert len(history) >= 4

    # Verify transitions in order
    assert history[0]["new_status"] == "pending_approval"
    assert history[1]["old_status"] == "pending_approval"
    assert history[1]["new_status"] == "approved_processing"
    assert history[1]["changed_by"] == staff.id

    assert history[2]["old_status"] == "approved_processing"
    assert history[2]["new_status"] == "dispatched"
    assert history[2]["changed_by"] == staff.id
    assert history[2]["changed_by_name"] == "Manoj Kumar"
    assert history[2]["remarks"] == "Dispatched with BlueDart AWB #998877"

    assert history[3]["old_status"] == "dispatched"
    assert history[3]["new_status"] == "delivered"
    assert history[3]["changed_by"] == staff.id
    assert history[3]["changed_by_name"] == "Manoj Kumar"
    assert history[3]["remarks"] == "Received by store manager Vikas"

    # Step 6: Verify direct database persistence
    db_session.expire_all()
    db_order = db_session.get(Order, order.id)
    assert db_order.status == "delivered"

    all_db_history = (
        db_session.query(OrderStatusHistory)
        .filter_by(order_id=order.id)
        .order_by(OrderStatusHistory.id.asc())
        .all()
    )
    assert len(all_db_history) >= 4
    assert all_db_history[-1].new_status == "delivered"
    assert all_db_history[-1].changed_by == staff.id
    assert all_db_history[-1].remarks == "Received by store manager Vikas"
