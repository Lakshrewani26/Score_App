from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.config import settings
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
    StaffProfile,
    StockRequest,
    StockRequestItem,
    StockRequestStatusHistory,
    User,
)

TEST_SECRET_KEY = "test-secret-key-score-app-admin-panel-minimum-32-chars-long"


@pytest.fixture(autouse=True)
def configure_test_jwt_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "jwt_secret_key", TEST_SECRET_KEY)
    monkeypatch.setattr(settings, "jwt_algorithm", "HS256")
    monkeypatch.setattr(settings, "jwt_access_token_expire_minutes", 60)


@pytest.fixture
def client() -> Generator[TestClient, None, None]:
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
            StockRequest.__table__,
            StockRequestItem.__table__,
            StockRequestStatusHistory.__table__,
        ],
    )

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine, expire_on_commit=False) as db:
            yield db

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)
    engine.dispose()


@pytest.fixture
def seed_data(client: TestClient) -> dict[str, Any]:
    with next(app.dependency_overrides[get_db]()) as session:
        # Create Admin
        admin = User(
            name="Super Admin",
            mobile="9876543210",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)

        # Create Partner
        partner = User(
            name="Rajesh Auto",
            mobile="9876543211",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner)
        session.flush()

        partner_profile = PartnerProfile(
            user_id=partner.id,
            business_name="Rajesh Auto Spares",
            business_address="123 Industrial Area, Pune",
            partner_code="RAJ-001",
        )
        session.add(partner_profile)

        # Create Second Partner
        partner2 = User(
            name="Amit Motors",
            mobile="9876543212",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner2)
        session.flush()

        partner_profile2 = PartnerProfile(
            user_id=partner2.id,
            business_name="Amit Motors Delhi",
            business_address="45 Connaught Place, Delhi",
            partner_code="AMT-002",
        )
        session.add(partner_profile2)

        # Create Staff
        staff = User(
            name="Vikram Staff",
            mobile="9876543213",
            password_hash=hash_password("staffSecret123"),
            role="staff",
            is_active=True,
        )
        session.add(staff)
        session.flush()

        staff_profile = StaffProfile(
            user_id=staff.id,
            staff_id="STF-101",
        )
        session.add(staff_profile)

        # Create Customer
        customer = User(
            name="Pooja Customer",
            mobile="9876543214",
            password_hash=hash_password("custSecret123"),
            role="customer",
            is_active=True,
        )
        session.add(customer)
        session.flush()

        # Create Category and Products
        cat = ProductCategory(name="Braking Systems", is_active=True)
        session.add(cat)
        session.flush()

        prod1 = Product(
            category_id=cat.id,
            product_code="BRK-001",
            name="Front Disc Brake Pad",
            description="High friction disc pad",
            vehicle_type="2-Wheeler",
            price=Decimal("450.00"),
            is_active=True,
        )
        prod2 = Product(
            category_id=cat.id,
            product_code="BRK-002",
            name="Rear Brake Drum",
            description="Heavy duty drum",
            vehicle_type="3-Wheeler",
            price=Decimal("850.00"),
            is_active=True,
        )
        prod3 = Product(
            category_id=cat.id,
            product_code="BRK-003",
            name="Universal Brake Fluid DOT4",
            description="High temperature brake fluid",
            vehicle_type="Both",
            price=Decimal("180.00"),
            is_active=True,
        )
        session.add_all([prod1, prod2, prod3])
        session.flush()

        # Seed Orders
        # Order 1: pending_approval
        order1 = Order(
            order_number="ORD-2025-001",
            partner_id=partner.id,
            status="pending_approval",
            notes="Please expedite shipment",
            created_at=datetime.now(timezone.utc) - timedelta(days=2),
        )
        session.add(order1)
        session.flush()

        item1_1 = OrderItem(
            order_id=order1.id,
            product_id=prod1.id,
            quantity=10,
            unit_price=Decimal("450.00"),
        )
        session.add(item1_1)

        # Order 2: approved_processing
        order2 = Order(
            order_number="ORD-2025-002",
            partner_id=partner.id,
            status="approved_processing",
            notes="Staff approved",
            created_at=datetime.now(timezone.utc) - timedelta(days=1),
            approved_by=staff.id,
            approved_at=datetime.now(timezone.utc) - timedelta(hours=12),
        )
        session.add(order2)
        session.flush()

        item2_1 = OrderItem(
            order_id=order2.id,
            product_id=prod2.id,
            quantity=5,
            unit_price=Decimal("850.00"),
        )
        item2_2 = OrderItem(
            order_id=order2.id,
            product_id=prod3.id,
            quantity=2,
            unit_price=Decimal("180.00"),
        )
        session.add_all([item2_1, item2_2])

        hist2 = OrderStatusHistory(
            order_id=order2.id,
            old_status="pending_approval",
            new_status="approved_processing",
            changed_by=staff.id,
            changed_at=datetime.now(timezone.utc) - timedelta(hours=12),
            remarks="Approved by Vikram",
        )
        session.add(hist2)

        # Order 3: delivered (by Amit Motors)
        order3 = Order(
            order_number="ORD-2025-003",
            partner_id=partner2.id,
            status="delivered",
            notes="Delivered order",
            created_at=datetime.now(timezone.utc) - timedelta(days=5),
            approved_by=staff.id,
            approved_at=datetime.now(timezone.utc) - timedelta(days=4),
        )
        session.add(order3)
        session.flush()

        item3_1 = OrderItem(
            order_id=order3.id,
            product_id=prod1.id,
            quantity=20,
            unit_price=Decimal("450.00"),
        )
        session.add(item3_1)

        # Seed Stock Requests
        sr1 = StockRequest(
            request_number="REQ-2025-001",
            partner_id=partner.id,
            status="pending_approval",
            notes="Need emergency stock",
            created_at=datetime.now(timezone.utc) - timedelta(hours=6),
        )
        session.add(sr1)
        session.flush()

        sri1 = StockRequestItem(
            stock_request_id=sr1.id,
            product_id=prod1.id,
            quantity=50,
        )
        session.add(sri1)

        sr2 = StockRequest(
            request_number="REQ-2025-002",
            partner_id=partner2.id,
            status="approved",
            notes="Seasonal buffer request",
            created_at=datetime.now(timezone.utc) - timedelta(days=3),
            reviewed_by=staff.id,
            reviewed_at=datetime.now(timezone.utc) - timedelta(days=2),
        )
        session.add(sr2)
        session.flush()

        sri2 = StockRequestItem(
            stock_request_id=sr2.id,
            product_id=prod2.id,
            quantity=15,
        )
        session.add(sri2)

        session.commit()

        return {
            "admin_id": admin.id,
            "partner_id": partner.id,
            "partner2_id": partner2.id,
            "staff_id": staff.id,
            "customer_id": customer.id,
            "order1_id": order1.id,
            "order2_id": order2.id,
            "order3_id": order3.id,
            "stock_request1_id": sr1.id,
            "stock_request2_id": sr2.id,
        }


def _auth_header(user_id: int, role: str) -> dict[str, str]:
    token = create_access_token(subject=str(user_id), role=role)
    return {"Authorization": f"Bearer {token}"}


# ===========================================================================
# Authorization and Security Tests
# ===========================================================================

def test_orders_requires_authentication(client: TestClient, seed_data: dict[str, Any]) -> None:
    resp = client.get("/api/v1/admin/orders")
    assert resp.status_code == 401


def test_orders_rejects_non_admin_roles(client: TestClient, seed_data: dict[str, Any]) -> None:
    # Customer
    resp = client.get(
        "/api/v1/admin/orders",
        headers=_auth_header(seed_data["customer_id"], "customer"),
    )
    assert resp.status_code == 403

    # Partner
    resp = client.get(
        "/api/v1/admin/orders",
        headers=_auth_header(seed_data["partner_id"], "partner"),
    )
    assert resp.status_code == 403

    # Staff
    resp = client.get(
        "/api/v1/admin/orders",
        headers=_auth_header(seed_data["staff_id"], "staff"),
    )
    assert resp.status_code == 403


def test_stock_requests_rejects_non_admin_roles(client: TestClient, seed_data: dict[str, Any]) -> None:
    resp = client.get(
        "/api/v1/admin/stock-requests",
        headers=_auth_header(seed_data["staff_id"], "staff"),
    )
    assert resp.status_code == 403


# ===========================================================================
# List Orders Tests
# ===========================================================================

def test_list_orders_success(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/orders", headers=headers)
    assert resp.status_code == 200

    data = resp.json()
    assert "items" in data
    assert "pagination" in data
    assert data["total"] == 3
    assert len(data["items"]) == 3

    # Newest order first
    items = data["items"]
    assert items[0]["order_number"] == "ORD-2025-002"
    assert items[0]["business_name"] == "Rajesh Auto Spares"
    assert items[0]["item_count"] == 2
    assert items[0]["total_quantity"] == 7
    # 5 * 850 + 2 * 180 = 4250 + 360 = 4610.00
    assert Decimal(str(items[0]["order_total"])) == Decimal("4610.00")


def test_list_orders_pagination(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/orders?page=1&page_size=2", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) == 2
    assert data["total"] == 3
    assert data["page"] == 1
    assert data["page_size"] == 2
    assert data["total_pages"] == 2

    # Second page
    resp2 = client.get("/api/v1/admin/orders?page=2&page_size=2", headers=headers)
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert len(data2["items"]) == 1
    assert data2["page"] == 2


def test_list_orders_search_by_order_number(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/orders?search=ORD-2025-003", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["order_number"] == "ORD-2025-003"
    assert data["items"][0]["business_name"] == "Amit Motors Delhi"


def test_list_orders_search_by_business_name(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/orders?search=Delhi", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["business_name"] == "Amit Motors Delhi"


def test_list_orders_filter_by_status(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/orders?status=pending_approval", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["items"][0]["order_number"] == "ORD-2025-001"


def test_list_orders_filter_by_vehicle_type(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")

    # 3-Wheeler filter
    resp = client.get("/api/v1/admin/orders?vehicle_type=3-Wheeler", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    # Order 2 contains Rear Brake Drum (3-Wheeler) and DOT4 (Both)
    assert any(o["order_number"] == "ORD-2025-002" for o in data["items"])


def test_list_orders_filter_by_date_range(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ten_days_ago = (datetime.now(timezone.utc) - timedelta(days=10)).strftime("%Y-%m-%d")

    resp = client.get(f"/api/v1/admin/orders?date_from={ten_days_ago}&date_to={today}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["total"] == 3


# ===========================================================================
# Order Detail Tests
# ===========================================================================

def test_get_order_detail_success(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    order_id = seed_data["order2_id"]

    resp = client.get(f"/api/v1/admin/orders/{order_id}", headers=headers)
    assert resp.status_code == 200
    data = resp.json()

    assert data["id"] == order_id
    assert data["order_number"] == "ORD-2025-002"
    assert data["status"] == "approved_processing"
    assert data["business_name"] == "Rajesh Auto Spares"
    assert data["approved_by_name"] == "Vikram Staff"

    # Items
    assert len(data["items"]) == 2
    item1 = next(i for i in data["items"] if i["product_code"] == "BRK-002")
    assert item1["quantity"] == 5
    assert Decimal(str(item1["unit_price"])) == Decimal("850.00")
    assert Decimal(str(item1["subtotal"])) == Decimal("4250.00")

    # Status history
    assert len(data["status_history"]) == 1
    assert data["status_history"][0]["new_status"] == "approved_processing"
    assert data["status_history"][0]["changed_by_name"] == "Vikram Staff"


def test_get_order_detail_not_found(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/orders/99999", headers=headers)
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()


# ===========================================================================
# Admin Order Status Mutation Tests
# ===========================================================================

def test_admin_cannot_bypass_staff_approval(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    order_id = seed_data["order1_id"]  # pending_approval

    resp = client.patch(
        f"/api/v1/admin/orders/{order_id}/status",
        headers=headers,
        json={"status": "dispatched", "remarks": "Trying to bypass approval"},
    )
    assert resp.status_code == 400
    assert "pending staff approval" in resp.json()["detail"].lower()


def test_admin_order_progression_dispatched_and_delivered(
    client: TestClient, seed_data: dict[str, Any]
) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    order_id = seed_data["order2_id"]  # currently approved_processing

    # 1. Invalid jump: approved_processing directly to delivered
    resp_invalid = client.patch(
        f"/api/v1/admin/orders/{order_id}/status",
        headers=headers,
        json={"status": "delivered", "remarks": "Premature delivery"},
    )
    assert resp_invalid.status_code == 400
    assert "dispatched" in resp_invalid.json()["detail"].lower()

    # 2. Valid progression: approved_processing -> dispatched
    resp_dispatch = client.patch(
        f"/api/v1/admin/orders/{order_id}/status",
        headers=headers,
        json={"status": "dispatched", "remarks": "Courier consignment #98124"},
    )
    assert resp_dispatch.status_code == 200
    data_dispatched = resp_dispatch.json()
    assert data_dispatched["status"] == "dispatched"
    assert len(data_dispatched["status_history"]) == 2
    assert data_dispatched["status_history"][-1]["new_status"] == "dispatched"
    assert data_dispatched["status_history"][-1]["changed_by_name"] == "Super Admin"
    assert data_dispatched["status_history"][-1]["remarks"] == "Courier consignment #98124"

    # 3. Valid progression: dispatched -> delivered
    resp_deliver = client.patch(
        f"/api/v1/admin/orders/{order_id}/status",
        headers=headers,
        json={"status": "delivered", "remarks": "Received by Rajesh"},
    )
    assert resp_deliver.status_code == 200
    data_delivered = resp_deliver.json()
    assert data_delivered["status"] == "delivered"
    assert len(data_delivered["status_history"]) == 3

    # 4. Terminal state: delivered cannot be modified
    resp_terminal = client.patch(
        f"/api/v1/admin/orders/{order_id}/status",
        headers=headers,
        json={"status": "dispatched", "remarks": "Try to revert"},
    )
    assert resp_terminal.status_code == 400
    assert "already delivered" in resp_terminal.json()["detail"].lower()


# ===========================================================================
# Stock Requests Tests (Read-Only)
# ===========================================================================

def test_list_stock_requests_success(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/stock-requests", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2

    # Verify items and quantities
    req1 = next(r for r in data["items"] if r["request_number"] == "REQ-2025-001")
    assert req1["status"] == "pending_approval"
    assert req1["business_name"] == "Rajesh Auto Spares"
    assert req1["item_count"] == 1
    assert req1["total_quantity"] == 50


def test_get_stock_request_detail_success(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    req_id = seed_data["stock_request1_id"]

    resp = client.get(f"/api/v1/admin/stock-requests/{req_id}", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["request_number"] == "REQ-2025-001"
    assert len(data["items"]) == 1
    assert data["items"][0]["product_code"] == "BRK-001"
    assert data["items"][0]["quantity"] == 50


def test_get_stock_request_detail_not_found(client: TestClient, seed_data: dict[str, Any]) -> None:
    headers = _auth_header(seed_data["admin_id"], "admin")
    resp = client.get("/api/v1/admin/stock-requests/99999", headers=headers)
    assert resp.status_code == 404
