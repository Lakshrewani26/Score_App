from __future__ import annotations

from decimal import Decimal
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
def db_session(test_engine):
    with Session(test_engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def client(test_engine):
    def override_get_db():
        with Session(test_engine, expire_on_commit=False) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


def _create_user(db: Session, *, name: str, mobile: str, role: str) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password("Password123!"),
        role=role,
        is_active=True,
    )
    db.add(user)
    db.flush()
    return user


def _create_partner(db: Session, *, name: str, mobile: str, business: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="partner")
    db.add(
        PartnerProfile(
            user_id=user.id,
            business_name=business,
            business_address="123 Market St",
            partner_code=f"P-{user.id}",
        )
    )
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="partner", mobile=user.mobile)
    return user, token


def _create_staff(db: Session, *, name: str, mobile: str, staff_code: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="staff")
    db.add(StaffProfile(user_id=user.id, staff_id=staff_code))
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="staff", mobile=user.mobile)
    return user, token


def _get_or_create_product(db: Session, suffix: str = "") -> Product:
    cat = db.query(ProductCategory).filter_by(name="General Parts").first()
    if not cat:
        cat = ProductCategory(name="General Parts", description="Test Category")
        db.add(cat)
        db.flush()
    code = f"PRD-{suffix or 'DEFAULT'}"
    prod = db.query(Product).filter_by(product_code=code).first()
    if not prod:
        prod = Product(
            category_id=cat.id,
            product_code=code,
            name=f"Test Brake Pad {suffix}",
            vehicle_type="2-Wheeler",
            price=Decimal("200.00"),
            is_active=True,
        )
        db.add(prod)
        db.commit()
        db.refresh(prod)
    return prod


def _create_order(
    db: Session, partner: User, *, status: str = "pending_approval", order_number: str = "ORD-TEST-1"
) -> Order:
    prod = _get_or_create_product(db, order_number)
    order = Order(
        order_number=order_number,
        partner_id=partner.id,
        status=status,
        notes="Test order",
    )
    db.add(order)
    db.flush()
    item = OrderItem(
        order_id=order.id,
        product_id=prod.id,
        quantity=2,
        unit_price=prod.price,
    )
    db.add(item)
    history = OrderStatusHistory(
        order_id=order.id,
        old_status=None,
        new_status=status,
        changed_by=partner.id,
        remarks="Created test order",
    )
    db.add(history)
    db.commit()
    db.refresh(order)
    return order


# =========================================================================
# Partner Order Cancellation Tests
# =========================================================================

def test_partner_can_cancel_own_pending_order(client: TestClient, db_session: Session) -> None:
    partner, token = _create_partner(db_session, name="Amit Partner", mobile="9811111111", business="Amit Spares")
    order = _create_order(db_session, partner, status="pending_approval", order_number="ORD-CNL-01")

    res = client.post(
        f"/api/v1/orders/{order.id}/cancel",
        headers={"Authorization": f"Bearer {token}"},
        json={"reason": "Customer changed mind"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["id"] == order.id
    assert data["status"] == "cancelled"

    # Verify database persistence & audit history
    db_session.expire_all()
    db_order = db_session.get(Order, order.id)
    assert db_order.status == "cancelled"
    history = db_session.query(OrderStatusHistory).filter_by(order_id=order.id).all()
    assert len(history) == 2
    assert history[-1].old_status == "pending_approval"
    assert history[-1].new_status == "cancelled"
    assert history[-1].changed_by == partner.id
    assert history[-1].remarks == "Customer changed mind"


def test_partner_cannot_cancel_approved_or_dispatched_or_delivered_order(
    client: TestClient, db_session: Session
) -> None:
    partner, token = _create_partner(db_session, name="Amit Partner", mobile="9811111112", business="Amit Spares")

    for non_cancellable_status in ["approved_processing", "dispatched", "delivered", "rejected"]:
        order = _create_order(db_session, partner, status=non_cancellable_status, order_number=f"ORD-NC-{non_cancellable_status}")
        res = client.post(
            f"/api/v1/orders/{order.id}/cancel",
            headers={"Authorization": f"Bearer {token}"},
            json={"reason": "Trying to cancel non-pending"},
        )
        assert res.status_code == 400
        assert "cannot be cancelled" in res.json()["detail"]


def test_partner_cannot_cancel_another_partners_order(
    client: TestClient, db_session: Session
) -> None:
    p1, token1 = _create_partner(db_session, name="Partner 1", mobile="9811111113", business="P1 Shop")
    p2, token2 = _create_partner(db_session, name="Partner 2", mobile="9811111114", business="P2 Shop")
    order = _create_order(db_session, p1, status="pending_approval", order_number="ORD-P1-01")

    res = client.post(
        f"/api/v1/orders/{order.id}/cancel",
        headers={"Authorization": f"Bearer {token2}"},  # Partner 2 trying to cancel Partner 1's order
    )
    assert res.status_code == 403
    assert "Access denied" in res.json()["detail"]


# =========================================================================
# Partner Dashboard Statistics Tests
# =========================================================================

def test_partner_dashboard_stats_empty(client: TestClient, db_session: Session) -> None:
    partner, token = _create_partner(db_session, name="New Partner", mobile="9811111115", business="New Shop")

    res = client.get(
        "/api/v1/orders/dashboard/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["total_points"] == 0
    assert data["points_used"] == 0
    assert data["remaining_balance"] == 0
    assert data["total_orders"] == 0
    assert data["pending_orders"] == 0
    assert data["processing_orders"] == 0
    assert data["dispatched_orders"] == 0
    assert data["delivered_orders"] == 0
    assert data["cancelled_orders"] == 0


def test_partner_dashboard_stats_with_data(client: TestClient, db_session: Session) -> None:
    partner, token = _create_partner(db_session, name="Busy Partner", mobile="9811111116", business="Busy Shop")

    # Create 2 pending, 1 delivered, 1 cancelled
    _create_order(db_session, partner, status="pending_approval", order_number="ORD-B-1")
    _create_order(db_session, partner, status="pending_approval", order_number="ORD-B-2")
    _create_order(db_session, partner, status="delivered", order_number="ORD-B-3")
    _create_order(db_session, partner, status="cancelled", order_number="ORD-B-4")

    # Add redeemed QR code for points
    batch = QrBatch(batch_number="BATCH-P1", qr_type="product", quantity=1)
    db_session.add(batch)
    db_session.flush()
    qr = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="tok123456789",
        code_data="data",
        points_awarded=150,
        status="redeemed",
        redeemed_by=partner.id,
    )
    db_session.add(qr)
    db_session.commit()

    res = client.get(
        "/api/v1/orders/dashboard/stats",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["total_points"] == 150
    assert data["remaining_balance"] == 150
    assert data["total_orders"] == 4
    assert data["pending_orders"] == 2
    assert data["processing_orders"] == 0
    assert data["delivered_orders"] == 1
    assert data["cancelled_orders"] == 1


# =========================================================================
# Staff Orders & Dashboard Tests
# =========================================================================

def test_staff_sees_orders_of_assigned_partner_only(
    client: TestClient, db_session: Session
) -> None:
    staff1, s1_token = _create_staff(db_session, name="Staff 1", mobile="9822222221", staff_code="STF-01")
    staff2, s2_token = _create_staff(db_session, name="Staff 2", mobile="9822222222", staff_code="STF-02")

    p1, _ = _create_partner(db_session, name="Assigned P1", mobile="9811111117", business="P1 Garage")
    p2, _ = _create_partner(db_session, name="Unassigned P2", mobile="9811111118", business="P2 Garage")

    # Assign p1 to staff1
    db_session.add(StaffPartnerAssignment(staff_id=staff1.id, partner_id=p1.id, is_active=True))
    db_session.commit()

    # Orders created by p1 and p2
    order_p1 = _create_order(db_session, p1, status="pending_approval", order_number="ORD-P1-LIVE")
    order_p2 = _create_order(db_session, p2, status="pending_approval", order_number="ORD-P2-LIVE")

    # Staff 1 lists orders -> sees order_p1, NOT order_p2
    res1 = client.get("/api/v1/staff/orders", headers={"Authorization": f"Bearer {s1_token}"})
    assert res1.status_code == 200
    order_ids_1 = [o["id"] for o in res1.json()]
    assert order_p1.id in order_ids_1
    assert order_p2.id not in order_ids_1

    # Staff 2 lists orders -> sees neither (no assignments)
    res2 = client.get("/api/v1/staff/orders", headers={"Authorization": f"Bearer {s2_token}"})
    assert res2.status_code == 200
    assert res2.json() == []


def test_staff_order_approval_and_rejection_workflow(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Staff Approver", mobile="9822222223", staff_code="STF-03")
    partner, _ = _create_partner(db_session, name="Dealer Partner", mobile="9811111119", business="Dealer Shop")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True))
    db_session.commit()

    order1 = _create_order(db_session, partner, status="pending_approval", order_number="ORD-APP-01")
    order2 = _create_order(db_session, partner, status="pending_approval", order_number="ORD-REJ-01")

    # 1. Staff approves order1
    res_app = client.post(
        f"/api/v1/staff/orders/{order1.id}/approve",
        headers={"Authorization": f"Bearer {token}"},
        json={"remarks": "Verified stock with warehouse"},
    )
    assert res_app.status_code == 200
    assert res_app.json()["status"] == "approved_processing"
    assert res_app.json()["approved_by"] == staff.id

    # Verify DB update and audit history
    db_session.expire_all()
    db_order1 = db_session.get(Order, order1.id)
    assert db_order1.status == "approved_processing"
    assert db_order1.approved_by == staff.id

    # 2. Staff rejects order2
    res_rej = client.post(
        f"/api/v1/staff/orders/{order2.id}/reject",
        headers={"Authorization": f"Bearer {token}"},
        json={"remarks": "Out of stock"},
    )
    assert res_rej.status_code == 200
    assert res_rej.json()["status"] == "rejected"
    db_session.expire_all()
    db_order2 = db_session.get(Order, order2.id)
    assert db_order2.status == "rejected"


def test_staff_cannot_approve_order_of_unassigned_partner(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Staff Stran", mobile="9822222224", staff_code="STF-04")
    partner, _ = _create_partner(db_session, name="Other Dealer", mobile="9811111120", business="Other Shop")
    # Not assigned!
    order = _create_order(db_session, partner, status="pending_approval", order_number="ORD-UNASS-1")

    res = client.post(
        f"/api/v1/staff/orders/{order.id}/approve",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 403


def test_staff_dashboard_statistics(client: TestClient, db_session: Session) -> None:
    staff, token = _create_staff(db_session, name="Staff Stats", mobile="9822222225", staff_code="STF-05")

    # Initial state (zero)
    res_zero = client.get("/api/v1/staff/dashboard", headers={"Authorization": f"Bearer {token}"})
    assert res_zero.status_code == 200
    assert res_zero.json() == {
        "dealers_count": 0,
        "pending_orders_count": 0,
        "pending_payments_count": 0,
    }

    # Assign 2 partners
    p1, _ = _create_partner(db_session, name="Dealer 1", mobile="9811111121", business="D1")
    p2, _ = _create_partner(db_session, name="Dealer 2", mobile="9811111122", business="D2")
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=p1.id, is_active=True))
    db_session.add(StaffPartnerAssignment(staff_id=staff.id, partner_id=p2.id, is_active=True))
    db_session.commit()

    # Create 3 orders for p1 (2 pending, 1 approved) and 1 for p2 (pending)
    _create_order(db_session, p1, status="pending_approval", order_number="ORD-D1-1")
    _create_order(db_session, p1, status="pending_approval", order_number="ORD-D1-2")
    _create_order(db_session, p1, status="approved_processing", order_number="ORD-D1-3")
    _create_order(db_session, p2, status="pending_approval", order_number="ORD-D2-1")

    # Add a payment record
    pay = StaffPaymentRecord(
        staff_id=staff.id,
        partner_id=p1.id,
        amount=Decimal("5000.00"),
        payment_method="cash",
        status="recorded",
        recorded_by=staff.id,
    )
    db_session.add(pay)
    db_session.commit()

    res = client.get("/api/v1/staff/dashboard", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert data["dealers_count"] == 2
    assert data["pending_orders_count"] == 3  # 2 for p1 + 1 for p2 in pending_approval
    assert data["pending_payments_count"] == 1


def test_partner_order_creation_visible_to_assigned_staff_and_access_controls(
    client: TestClient, db_session: Session
) -> None:
    """Verifies end-to-end:
    1. Partner creates order via POST /api/v1/orders with initial 'pending_approval' status.
    2. Assigned Staff retrieves order via GET /api/v1/staff/orders?status=pending_approval.
    3. Unassigned Staff cannot view order in their list, cannot open detail, cannot download PDF.
    4. Assigned Staff can open order details and download PDF.
    5. Assigned Staff approves/rejects orders properly preserving remarks.
    """
    staff_assigned, staff_token = _create_staff(
        db_session, name="Assigned Staffer", mobile="9822222226", staff_code="STF-06"
    )
    staff_unassigned, unassigned_token = _create_staff(
        db_session, name="Stranger Staffer", mobile="9822222227", staff_code="STF-07"
    )
    partner, partner_token = _create_partner(
        db_session, name="Rajesh Dealer", mobile="9811111123", business="Rajesh Auto"
    )

    # Establish assignment between staff_assigned and partner
    db_session.add(
        StaffPartnerAssignment(staff_id=staff_assigned.id, partner_id=partner.id, is_active=True)
    )
    db_session.commit()

    # Create product with authorized price
    prod = _get_or_create_product(db_session, "E2E-1")

    # 1. Partner creates order via API
    create_res = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {partner_token}"},
        json={
            "items": [{"product_id": prod.id, "quantity": 3}],
            "notes": "Urgent delivery needed",
        },
    )
    assert create_res.status_code == 201
    created_order = create_res.json()
    order_id = created_order["id"]
    assert created_order["status"] == "pending_approval"
    assert created_order["partner_id"] == partner.id
    assert created_order["item_count"] == 1
    assert created_order["total_quantity"] == 3

    # 2. Assigned Staff lists orders
    staff_orders_res = client.get(
        "/api/v1/staff/orders?status=pending_approval",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert staff_orders_res.status_code == 200
    assigned_orders = staff_orders_res.json()
    assert any(o["id"] == order_id for o in assigned_orders)

    # 3. Unassigned Staff lists orders -> order NOT present
    unassigned_orders_res = client.get(
        "/api/v1/staff/orders?status=pending_approval",
        headers={"Authorization": f"Bearer {unassigned_token}"},
    )
    assert unassigned_orders_res.status_code == 200
    assert not any(o["id"] == order_id for o in unassigned_orders_res.json())

    # 4. Unassigned Staff cannot view order detail on /api/v1/staff/orders/{id} or /api/v1/orders/{id}
    unassigned_detail_res1 = client.get(
        f"/api/v1/staff/orders/{order_id}",
        headers={"Authorization": f"Bearer {unassigned_token}"},
    )
    assert unassigned_detail_res1.status_code == 403

    unassigned_detail_res2 = client.get(
        f"/api/v1/orders/{order_id}",
        headers={"Authorization": f"Bearer {unassigned_token}"},
    )
    assert unassigned_detail_res2.status_code == 403

    # 5. Unassigned Staff cannot download PDF
    unassigned_pdf_res = client.get(
        f"/api/v1/orders/{order_id}/pdf",
        headers={"Authorization": f"Bearer {unassigned_token}"},
    )
    assert unassigned_pdf_res.status_code == 403

    # 6. Assigned Staff can view order detail
    assigned_detail_res = client.get(
        f"/api/v1/staff/orders/{order_id}",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert assigned_detail_res.status_code == 200
    assert assigned_detail_res.json()["id"] == order_id

    # 7. Assigned Staff can view order detail on /api/v1/orders/{id} and download PDF
    order_detail_res = client.get(
        f"/api/v1/orders/{order_id}",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert order_detail_res.status_code == 200
    assert order_detail_res.json()["id"] == order_id

    pdf_res = client.get(
        f"/api/v1/orders/{order_id}/pdf",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert pdf_res.status_code == 200
    assert pdf_res.headers["content-type"] == "application/pdf"

    # 8. Assigned Staff rejects with remarks
    rej_res = client.post(
        f"/api/v1/staff/orders/{order_id}/reject",
        headers={"Authorization": f"Bearer {staff_token}"},
        json={"remarks": "Insufficient stock in warehouse"},
    )
    assert rej_res.status_code == 200
    assert rej_res.json()["status"] == "rejected"
    assert "Insufficient stock in warehouse" in rej_res.json()["notes"]

    # Verify history retained rejection remarks
    db_session.expire_all()
    history = db_session.query(OrderStatusHistory).filter_by(order_id=order_id).all()
    assert history[-1].new_status == "rejected"
    assert history[-1].remarks == "Insufficient stock in warehouse"
