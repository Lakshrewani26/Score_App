from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any
from zoneinfo import ZoneInfo

import pytest
import reportlab.rl_config
reportlab.rl_config.pageCompression = 0
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
from app.services.pdf_service import (
    extract_city_from_address,
    extract_clean_order_notes,
    generate_order_pdf,
)

TEST_SECRET_KEY = "test-secret-key-score-app-admin-panel-minimum-32-chars-long"


@pytest.fixture(autouse=True)
def configure_test_jwt_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "jwt_secret_key", TEST_SECRET_KEY)
    monkeypatch.setattr(settings, "jwt_algorithm", "HS256")
    monkeypatch.setattr(settings, "jwt_access_token_expire_minutes", 60)


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
            StockRequest.__table__,
            StockRequestItem.__table__,
            StockRequestStatusHistory.__table__,
        ],
    )
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine) -> Generator[Session, None, None]:
    with Session(test_engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def client(test_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine, expire_on_commit=False) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


@pytest.fixture
def test_setup(db_session: Session) -> dict[str, Any]:
    # 1. Admin
    admin = User(
        name="Super Admin",
        mobile="9876543210",
        password_hash=hash_password("adminSecret123"),
        role="admin",
        is_active=True,
    )
    # 2. Partner 1 (Pune)
    partner1 = User(
        name="Rajesh Sharma",
        mobile="9876543211",
        password_hash=hash_password("partnerSecret123"),
        role="partner",
        is_active=True,
    )
    # 3. Partner 2 (Mumbai)
    partner2 = User(
        name="Sunil Patil",
        mobile="9876543212",
        password_hash=hash_password("partnerSecret123"),
        role="partner",
        is_active=True,
    )
    # 4. Staff
    staff = User(
        name="Vikram SalesStaff",
        mobile="9876543213",
        password_hash=hash_password("staffSecret123"),
        role="staff",
        is_active=True,
    )
    # 5. Customer
    customer = User(
        name="Anita Customer",
        mobile="9876543214",
        password_hash=hash_password("custSecret123"),
        role="customer",
        is_active=True,
    )
    db_session.add_all([admin, partner1, partner2, staff, customer])
    db_session.flush()

    prof1 = PartnerProfile(
        user_id=partner1.id,
        business_name="Rajesh Auto Spares",
        business_address="Plot 42, MIDC Bhosari, Pune - 411026",
        partner_code="RAJ-001",
    )
    prof2 = PartnerProfile(
        user_id=partner2.id,
        business_name="Patil Wheels Mumbai",
        business_address="Shop 12, Link Road, Andheri West, Mumbai 400053",
        partner_code="PAT-002",
    )
    staff_prof = StaffProfile(user_id=staff.id, staff_id="STF-001")
    db_session.add_all([prof1, prof2, staff_prof])
    db_session.flush()

    # Category and Products
    cat = ProductCategory(name="Brakes & Transmission", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p1 = Product(
        category_id=cat.id,
        product_code="BRK-PAD-01",
        name="Ceramic Disc Brake Pad Set",
        vehicle_type="2-Wheeler",
        price=Decimal("600.00"),
        list_price=Decimal("550.00"),
        is_active=True,
    )
    p2 = Product(
        category_id=cat.id,
        product_code="BRK-DRM-02",
        name="Rear Brake Drum Assembly Heavy Duty",
        vehicle_type="3-Wheeler",
        price=Decimal("1200.00"),
        list_price=Decimal("1100.00"),
        is_active=True,
    )
    db_session.add_all([p1, p2])
    db_session.flush()

    # Order A: Partner-created normal order
    order_partner = Order(
        order_number="ORD-PTN-001",
        partner_id=partner1.id,
        created_by_user_id=partner1.id,
        status="pending_approval",
        notes="Transport: VRL Logistics Pune",
        subtotal_before_discount=Decimal("1100.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("110.00"),
        final_total=Decimal("990.00"),
        created_at=datetime.now(timezone.utc) - timedelta(days=2),
    )
    db_session.add(order_partner)
    db_session.flush()

    item_a1 = OrderItem(
        order_id=order_partner.id,
        product_id=p1.id,
        quantity=2,
        original_price=Decimal("550.00"),
        unit_price=Decimal("495.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
        discount_percentage=Decimal("10.00"),
        discount_amount=Decimal("55.00"),
        discounted_price=Decimal("495.00"),
    )
    db_session.add(item_a1)

    # Order B: Staff-created normal order
    order_staff = Order(
        order_number="ORD-STF-002",
        partner_id=partner2.id,
        created_by_user_id=staff.id,
        status="approved_processing",
        notes="Transport: Navata Road Transport",
        subtotal_before_discount=Decimal("2200.00"),
        discount_percentage=Decimal("5.00"),
        total_discount=Decimal("110.00"),
        final_total=Decimal("2090.00"),
        created_at=datetime.now(timezone.utc) - timedelta(days=1),
    )
    db_session.add(order_staff)
    db_session.flush()

    item_b1 = OrderItem(
        order_id=order_staff.id,
        product_id=p2.id,
        quantity=2,
        original_price=Decimal("1100.00"),
        unit_price=Decimal("1045.00"),
        mrp=Decimal("1200.00"),
        list_price=Decimal("1100.00"),
        discount_percentage=Decimal("5.00"),
        discount_amount=Decimal("55.00"),
        discounted_price=Decimal("1045.00"),
    )
    db_session.add(item_b1)

    # Order C: Historical order (created_by_user_id is NULL)
    order_hist = Order(
        order_number="ORD-HIST-003",
        partner_id=partner1.id,
        created_by_user_id=None,
        status="delivered",
        notes="Historical pre-migration order",
        subtotal_before_discount=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("550.00"),
        created_at=datetime.now(timezone.utc) - timedelta(days=30),
    )
    db_session.add(order_hist)
    db_session.flush()

    item_c1 = OrderItem(
        order_id=order_hist.id,
        product_id=p1.id,
        quantity=1,
        original_price=Decimal("550.00"),
        unit_price=Decimal("550.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        discount_amount=Decimal("0.00"),
        discounted_price=Decimal("550.00"),
    )
    db_session.add(item_c1)

    # Stock Request (MUST BE EXCLUDED FROM ALL ORDERS)
    stock_req = StockRequest(
        request_number="REQ-STOCK-999",
        partner_id=partner1.id,
        status="pending_approval",
        notes="Urgent inventory replenishment",
        created_at=datetime.now(timezone.utc) - timedelta(hours=3),
    )
    db_session.add(stock_req)
    db_session.flush()

    sr_item = StockRequestItem(
        stock_request_id=stock_req.id,
        product_id=p1.id,
        quantity=100,
    )
    db_session.add(sr_item)
    db_session.commit()

    admin_token = create_access_token(subject=str(admin.id), role="admin")
    partner_token = create_access_token(subject=str(partner1.id), role="partner")
    staff_token = create_access_token(subject=str(staff.id), role="staff")
    customer_token = create_access_token(subject=str(customer.id), role="customer")

    return {
        "admin": admin,
        "partner1": partner1,
        "partner2": partner2,
        "staff": staff,
        "customer": customer,
        "order_partner": order_partner,
        "order_staff": order_staff,
        "order_hist": order_hist,
        "stock_req": stock_req,
        "admin_token": admin_token,
        "partner_token": partner_token,
        "staff_token": staff_token,
        "customer_token": customer_token,
        "p1": p1,
        "p2": p2,
    }


# =========================================================================
# FEATURE 1: ADMIN ALL ORDERS TESTS
# =========================================================================

def test_admin_all_orders_includes_partner_and_staff_orders(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    headers = {"Authorization": f"Bearer {test_setup['admin_token']}"}
    response = client.get("/api/v1/admin/orders", headers=headers)
    assert response.status_code == 200

    data = response.json()
    assert "items" in data
    assert data["total"] == 3

    order_numbers = [item["order_number"] for item in data["items"]]
    assert "ORD-PTN-001" in order_numbers
    assert "ORD-STF-002" in order_numbers
    assert "ORD-HIST-003" in order_numbers

    # Verify partner-created order details
    ptn_order = next(i for i in data["items"] if i["order_number"] == "ORD-PTN-001")
    assert ptn_order["created_by_role"] == "partner"
    assert ptn_order["created_by_name"] == "Rajesh Sharma"
    assert ptn_order["created_by_user_id"] == test_setup["partner1"].id

    # Verify staff-created order details
    stf_order = next(i for i in data["items"] if i["order_number"] == "ORD-STF-002")
    assert stf_order["created_by_role"] == "staff"
    assert stf_order["created_by_name"] == "Vikram SalesStaff"
    assert stf_order["created_by_user_id"] == test_setup["staff"].id


def test_admin_all_orders_excludes_stock_requests(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    headers = {"Authorization": f"Bearer {test_setup['admin_token']}"}
    response = client.get("/api/v1/admin/orders", headers=headers)
    assert response.status_code == 200

    data = response.json()
    order_numbers = [item["order_number"] for item in data["items"]]
    # Strictly ensure stock requests are never included
    assert "REQ-STOCK-999" not in order_numbers
    assert not any("REQ-" in num for num in order_numbers)


def test_admin_all_orders_historical_orders_fallback(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    headers = {"Authorization": f"Bearer {test_setup['admin_token']}"}
    response = client.get("/api/v1/admin/orders", headers=headers)
    assert response.status_code == 200

    data = response.json()
    hist_order = next(i for i in data["items"] if i["order_number"] == "ORD-HIST-003")
    # For historical orders without explicit creator, creator is unknown / legacy and never inferred as Partner
    assert hist_order["created_by_role"] == "unknown"
    assert hist_order["created_by_name"] == "Unknown / Legacy"
    assert hist_order["created_by_user_id"] is None
    # Partner details remain intact
    assert hist_order["partner_id"] == test_setup["partner1"].id
    assert hist_order["partner_name"] == "Rajesh Sharma"


def test_admin_all_orders_creator_attribution_scenarios(db_session: Session) -> None:
    from app.routers.admin_orders import _build_order_summary

    # Setup base partner
    partner = User(
        name="Partner User",
        mobile="9876500001",
        password_hash=hash_password("password123"),
        role="partner",
        is_active=True,
    )
    db_session.add(partner)
    db_session.flush()

    partner_profile = PartnerProfile(
        user_id=partner.id,
        business_name="Partner Auto Parts",
        business_address="Shop 10, Pune, Maharashtra 411001",
        partner_code="PTN-001",
    )
    db_session.add(partner_profile)

    # Setup staff user
    staff = User(
        name="Staff User",
        mobile="9876500002",
        password_hash=hash_password("password123"),
        role="staff",
        is_active=True,
    )
    db_session.add(staff)
    db_session.flush()

    # Scenario 1: Partner creator
    order_ptn = Order(
        id=101,
        order_number="ORD-TEST-PTN",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        final_total=Decimal("100.00"),
        created_at=datetime.now(timezone.utc),
    )
    order_ptn.partner = partner
    order_ptn.created_by = partner
    summary_ptn = _build_order_summary(order_ptn)

    assert summary_ptn.created_by_user_id == partner.id
    assert summary_ptn.created_by_name == "Partner User"
    assert summary_ptn.created_by_role == "partner"
    assert summary_ptn.partner_id == partner.id
    assert summary_ptn.partner_name == "Partner User"
    assert summary_ptn.business_name == "Partner Auto Parts"

    # Scenario 2: Staff creator
    order_stf = Order(
        id=102,
        order_number="ORD-TEST-STF",
        partner_id=partner.id,
        created_by_user_id=staff.id,
        status="approved_processing",
        final_total=Decimal("200.00"),
        created_at=datetime.now(timezone.utc),
    )
    order_stf.partner = partner
    order_stf.created_by = staff
    summary_stf = _build_order_summary(order_stf)

    assert summary_stf.created_by_user_id == staff.id
    assert summary_stf.created_by_name == "Staff User"
    assert summary_stf.created_by_role == "staff"
    assert summary_stf.partner_id == partner.id
    assert summary_stf.partner_name == "Partner User"
    assert summary_stf.business_name == "Partner Auto Parts"

    # Scenario 3: Null creator with existing Partner
    order_null_creator = Order(
        id=103,
        order_number="ORD-TEST-NULL-CREATOR",
        partner_id=partner.id,
        created_by_user_id=None,
        status="delivered",
        final_total=Decimal("300.00"),
        created_at=datetime.now(timezone.utc),
    )
    order_null_creator.partner = partner
    order_null_creator.created_by = None
    summary_null = _build_order_summary(order_null_creator)

    assert summary_null.created_by_user_id is None
    assert summary_null.created_by_name == "Unknown / Legacy"
    assert summary_null.created_by_role == "unknown"
    # Never infer that an unknown creator is the Partner
    assert summary_null.created_by_role != "partner"
    assert summary_null.created_by_user_id != partner.id
    # Partner details remain intact
    assert summary_null.partner_id == partner.id
    assert summary_null.partner_name == "Partner User"
    assert summary_null.business_name == "Partner Auto Parts"

    # Scenario 4: Null creator with missing Partner
    order_missing_partner = Order(
        id=104,
        order_number="ORD-TEST-MISSING-PARTNER",
        partner_id=99999,
        created_by_user_id=None,
        status="delivered",
        final_total=Decimal("400.00"),
        created_at=datetime.now(timezone.utc),
    )
    order_missing_partner.partner = None
    order_missing_partner.created_by = None
    summary_missing_ptn = _build_order_summary(order_missing_partner)

    assert summary_missing_ptn.created_by_user_id is None
    assert summary_missing_ptn.created_by_name == "Unknown / Legacy"
    assert summary_missing_ptn.created_by_role == "unknown"
    assert summary_missing_ptn.partner_id == 99999
    assert summary_missing_ptn.partner_name == "User #99999"
    assert summary_missing_ptn.business_name is None
    assert summary_missing_ptn.partner_mobile == ""


def test_admin_all_orders_authorization_enforced(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    # 1. Unauthenticated
    resp_anon = client.get("/api/v1/admin/orders")
    assert resp_anon.status_code == 401

    # 2. Partner (forbidden)
    resp_ptn = client.get(
        "/api/v1/admin/orders",
        headers={"Authorization": f"Bearer {test_setup['partner_token']}"},
    )
    assert resp_ptn.status_code == 403

    # 3. Staff (forbidden)
    resp_stf = client.get(
        "/api/v1/admin/orders",
        headers={"Authorization": f"Bearer {test_setup['staff_token']}"},
    )
    assert resp_stf.status_code == 403

    # 4. Customer (forbidden)
    resp_cust = client.get(
        "/api/v1/admin/orders",
        headers={"Authorization": f"Bearer {test_setup['customer_token']}"},
    )
    assert resp_cust.status_code == 403

    # 5. Admin (allowed)
    resp_admin = client.get(
        "/api/v1/admin/orders",
        headers={"Authorization": f"Bearer {test_setup['admin_token']}"},
    )
    assert resp_admin.status_code == 200


def test_admin_all_orders_search_and_filters(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    headers = {"Authorization": f"Bearer {test_setup['admin_token']}"}

    # Search by order number
    r1 = client.get("/api/v1/admin/orders?search=ORD-STF", headers=headers)
    assert r1.status_code == 200
    assert r1.json()["total"] == 1
    assert r1.json()["items"][0]["order_number"] == "ORD-STF-002"

    # Search by creator name
    r2 = client.get("/api/v1/admin/orders?search=Vikram", headers=headers)
    assert r2.status_code == 200
    assert r2.json()["total"] == 1
    assert r2.json()["items"][0]["created_by_name"] == "Vikram SalesStaff"

    # Search by partner business name
    r3 = client.get("/api/v1/admin/orders?search=Patil", headers=headers)
    assert r3.status_code == 200
    assert r3.json()["total"] == 1
    assert r3.json()["items"][0]["order_number"] == "ORD-STF-002"

    # Filter by vehicle type
    r4 = client.get("/api/v1/admin/orders?vehicle_type=3-Wheeler", headers=headers)
    assert r4.status_code == 200
    assert any(i["order_number"] == "ORD-STF-002" for i in r4.json()["items"])

    # Filter by status
    r5 = client.get("/api/v1/admin/orders?status=pending_approval", headers=headers)
    assert r5.status_code == 200
    assert r5.json()["total"] == 1
    assert r5.json()["items"][0]["order_number"] == "ORD-PTN-001"

    # Pagination: page=1, page_size=1
    r6 = client.get("/api/v1/admin/orders?page=1&page_size=1", headers=headers)
    assert r6.status_code == 200
    assert len(r6.json()["items"]) == 1
    assert r6.json()["total"] == 3

    # Search by unknown / legacy creator
    r7 = client.get("/api/v1/admin/orders?search=legacy", headers=headers)
    assert r7.status_code == 200
    assert any(i["order_number"] == "ORD-HIST-003" for i in r7.json()["items"])


def test_admin_order_detail_is_read_only(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    headers = {"Authorization": f"Bearer {test_setup['admin_token']}"}
    order_id = test_setup["order_staff"].id

    # Fetch detail
    r = client.get(f"/api/v1/admin/orders/{order_id}", headers=headers)
    assert r.status_code == 200
    data = r.json()

    assert data["order_number"] == "ORD-STF-002"
    assert data["created_by_role"] == "staff"
    assert data["created_by_name"] == "Vikram SalesStaff"
    assert len(data["items"]) == 1
    assert data["items"][0]["product_name"] == "Rear Brake Drum Assembly Heavy Duty"
    # Status remains untouched
    assert data["status"] == "approved_processing"


def test_admin_orders_pdf_endpoint(
    client: TestClient, test_setup: dict[str, Any]
) -> None:
    headers = {"Authorization": f"Bearer {test_setup['admin_token']}"}
    order_id = test_setup["order_partner"].id

    # Admin requests PDF
    resp = client.get(f"/api/v1/admin/orders/{order_id}/pdf", headers=headers)
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/pdf"
    assert "Score_Order_ORD-PTN-001.pdf" in resp.headers["content-disposition"]
    assert resp.content.startswith(b"%PDF")

    # Unauthorized role blocked
    resp_staff = client.get(
        f"/api/v1/admin/orders/{order_id}/pdf",
        headers={"Authorization": f"Bearer {test_setup['staff_token']}"},
    )
    assert resp_staff.status_code == 403

    # Non-existent order returns 404
    resp_404 = client.get("/api/v1/admin/orders/999999/pdf", headers=headers)
    assert resp_404.status_code == 404


# =========================================================================
# FEATURE 2: NEW SALES ORDER PDF FORMAT TESTS
# =========================================================================

def test_sales_order_pdf_content_and_layout(
    db_session: Session, test_setup: dict[str, Any]
) -> None:
    order = test_setup["order_partner"]
    pdf_bytes = generate_order_pdf(order)

    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # 1. Header
    assert "SALES ORDER" in pdf_text

    # 2. Partner / Business Information
    assert "Rajesh Auto Spares" in pdf_text
    assert "Plot 42, MIDC Bhosari" in pdf_text
    assert "9876543211" in pdf_text
    # Transport Name is always '-' (never infer from notes)
    assert "Transport Name:" in pdf_text
    idx_trans = pdf_text.find("Transport Name:")
    trans_snippet = pdf_text[idx_trans : idx_trans + 60]
    assert "( -)" in trans_snippet or "(-)" in trans_snippet
    assert "VRL Logistics" not in trans_snippet
    # Genuine order notes appear separately under Order Notes
    assert "Order Notes:" in pdf_text
    assert "VRL Logistics Pune" in pdf_text

    # 3. Order Information
    assert "ORD-PTN-001" in pdf_text

    # 4. Product Table Columns
    assert "Product" in pdf_text
    assert "Qty." in pdf_text
    assert "MRP" in pdf_text
    assert "LIST" in pdf_text
    assert "Stock" in pdf_text
    assert "No." in pdf_text

    # 5. Product Item & Snapshots
    assert "Ceramic Disc Brake Pad Set" in pdf_text
    assert "600.00" in pdf_text  # MRP snapshot
    assert "550.00" in pdf_text  # List price snapshot
    assert "495.00" in pdf_text  # Final discounted line rate

    # Stock column safe fallback: no live stock is displayed
    # (Stock column displays "-")
    assert "-" in pdf_text

    # 6. Totals Section
    assert "Total Quantity:" in pdf_text
    assert "Subtotal Before Discount:" in pdf_text
    assert "Partner Discount" in pdf_text
    assert "Final Order Total:" in pdf_text
    assert "990.00" in pdf_text

    # 7. Signature Section
    assert "Partner / Customer Confirmation" in pdf_text
    assert "Authorized Signatory" in pdf_text

    # 8. Footer: Print timestamp and City extracted from address
    assert "Print Date & Time:" in pdf_text
    assert "Pune" in pdf_text


def test_sales_order_pdf_temporary_mrp_fallback(db_session: Session) -> None:
    partner = User(
        name="Fallback Partner",
        mobile="9876543299",
        password_hash=hash_password("pw123"),
        role="partner",
        is_active=True,
    )
    db_session.add(partner)
    db_session.flush()

    prof = PartnerProfile(
        user_id=partner.id,
        business_name="Fallback Spares Ltd",
        business_address="GIDC Sector 10, Gandhinagar, Gujarat",
        partner_code="FB-001",
    )
    db_session.add(prof)

    cat = ProductCategory(name="Cables", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="CBL-001",
        name="Clutch Cable",
        vehicle_type="2-Wheeler",
        price=Decimal("300.00"),
        list_price=None,  # list_price is NULL -> triggers fallback
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    order = Order(
        order_number="ORD-FALLBACK-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("300.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("300.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("300.00"),
        unit_price=Decimal("300.00"),
        mrp=Decimal("300.00"),
        list_price=None,  # Fallback to MRP
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    assert "SALES ORDER" in pdf_text
    assert "Temporary MRP fallback" in pdf_text
    assert "Note: Items marked with" in pdf_text


def test_sales_order_pdf_city_extraction_helper() -> None:
    # 1. Comma separated with pincode
    assert extract_city_from_address("Plot 42, MIDC Bhosari, Pune - 411026") == "Pune"
    # 2. Multi-line address
    addr_multi = "Shop 12, Link Road\nAndheri West\nMumbai - 400053"
    assert extract_city_from_address(addr_multi) == "Mumbai"
    # 3. Capital territory / two-word city
    assert extract_city_from_address("45 Connaught Place, New Delhi 110001") == "New Delhi"
    # 4. Empty / None fallback
    assert extract_city_from_address(None) == "N/A"
    assert extract_city_from_address("") == "N/A"
    assert extract_city_from_address("   ") == "N/A"


def test_sales_order_pdf_staff_created_order(
    db_session: Session, test_setup: dict[str, Any]
) -> None:
    order = test_setup["order_staff"]
    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")
    assert "SALES ORDER" in pdf_text
    assert "Patil Wheels Mumbai" in pdf_text
    assert "Transport Name:" in pdf_text
    idx_trans = pdf_text.find("Transport Name:")
    trans_snippet = pdf_text[idx_trans : idx_trans + 60]
    assert "( -)" in trans_snippet or "(-)" in trans_snippet
    assert "Navata Road Transport" not in trans_snippet
    assert "Order Notes:" in pdf_text
    assert "Navata Road Transport" in pdf_text
    assert "ORD-STF-002" in pdf_text
    assert "Mumbai" in pdf_text
    assert "2,090.00" in pdf_text


def test_sales_order_pdf_multi_page_and_long_names(db_session: Session) -> None:
    partner = User(
        name="Mega Distributor",
        mobile="9898989898",
        password_hash=hash_password("pw123"),
        role="partner",
        is_active=True,
    )
    db_session.add(partner)
    db_session.flush()

    prof = PartnerProfile(
        user_id=partner.id,
        business_name="Mega Auto Distribution Pvt Ltd",
        business_address="Survey No 102, Near Toll Plaza, Ahmedabad Highway, Surat 395001",
        partner_code="MGA-001",
    )
    db_session.add(prof)

    cat = ProductCategory(name="Heavy Duty Parts", is_active=True)
    db_session.add(cat)
    db_session.flush()

    order = Order(
        order_number="ORD-BULK-001",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="approved_processing",
        notes="Transport: National Cargo Express Service",
        subtotal_before_discount=Decimal("50000.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("5000.00"),
        final_total=Decimal("45000.00"),
    )
    db_session.add(order)
    db_session.flush()

    # Add 25 products with long descriptions to test multi-page flow and table header repeat
    for i in range(1, 26):
        p = Product(
            category_id=cat.id,
            product_code=f"PRD-BULK-{i:03d}",
            name=f"Heavy Duty Premium Synthetic High Endurance Component Item Variant Series {i} For Commercial Applications",
            vehicle_type="Both",
            price=Decimal("2000.00"),
            list_price=Decimal("2000.00"),
            is_active=True,
        )
        db_session.add(p)
        db_session.flush()

        item = OrderItem(
            order_id=order.id,
            product_id=p.id,
            quantity=1,
            original_price=Decimal("2000.00"),
            unit_price=Decimal("1800.00"),
            mrp=Decimal("2200.00"),
            list_price=Decimal("2000.00"),
            discount_percentage=Decimal("10.00"),
            discount_amount=Decimal("200.00"),
            discounted_price=Decimal("1800.00"),
        )
        db_session.add(item)

    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")
    assert "SALES ORDER" in pdf_text
    assert "Mega Auto Distribution Pvt Ltd" in pdf_text
    assert "Surat" in pdf_text
    assert "45,000.00" in pdf_text


def test_sales_order_pdf_print_timestamp_uses_ist_regardless_of_server_tz(
    test_setup: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    """
    Spec: Printing timestamp must always use Asia/Kolkata (IST),
    even when the backend server runs in UTC or another timezone.
    """
    import app.services.pdf_service as pdf_mod

    # Fixed UTC instant: 2026-11-18 10:00:00 UTC
    # In Asia/Kolkata (+05:30), this exact moment is 2026-11-18 15:30:00 (03:30 PM).
    fixed_utc = datetime(2026, 11, 18, 10, 0, 0, tzinfo=timezone.utc)

    class MockDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is not None:
                return fixed_utc.astimezone(tz)
            # If server runs in UTC and called now() without tz, it would be 10:00 AM UTC
            return fixed_utc

    monkeypatch.setattr(pdf_mod, "datetime", MockDateTime)

    order = test_setup["order_partner"]
    pdf_bytes = generate_order_pdf(order)
    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # Timestamp must reflect Asia/Kolkata time (03:30 PM), NOT UTC (10:00 AM)
    assert "Print Date & Time: 18 Nov 2026, 03:30 PM" in pdf_text
    assert "10:00 AM" not in pdf_text


def test_sales_order_pdf_transport_name_always_dash(
    db_session: Session, test_setup: dict[str, Any]
) -> None:
    """
    Spec: Transport Name must always display '-' until a dedicated field is implemented.
    Never use order.notes or infer transport details from any remarks/metadata.
    """
    partner = test_setup["partner1"]
    p = test_setup["p1"]

    order = Order(
        order_number="ORD-TRANS-DASH-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        # Notes explicitly mentions transport, but Transport Name must still be '-'
        notes="Transport: VRL Logistics Express Pune Branch",
        subtotal_before_discount=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("550.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("550.00"),
        unit_price=Decimal("550.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # Transport Name is strictly '-'
    assert "Transport Name:" in pdf_text
    idx_trans = pdf_text.find("Transport Name:")
    trans_snippet = pdf_text[idx_trans : idx_trans + 60]
    assert "( -)" in trans_snippet or "(-)" in trans_snippet
    assert "VRL Logistics" not in trans_snippet
    assert "Express Pune Branch" not in trans_snippet
    # Notes are preserved under Order Notes, NOT Transport Name
    assert "Order Notes:" in pdf_text
    assert "Transport: VRL Logistics Express Pune Branch" in pdf_text


def test_sales_order_pdf_order_notes_and_metadata_exclusion(
    db_session: Session, test_setup: dict[str, Any]
) -> None:
    """
    Spec:
    - Genuine Partner-entered and Staff-entered notes remain visible.
    - [Created by Staff: ...], [idempotency_key:...], [Rejection remarks: ...] are not visible.
    - Placed by Staff for Dealer #123 is not visible.
    - Mixed genuine notes and metadata retain only genuine notes.
    - If all notes are metadata, the PDF omits the Order Notes section.
    - Stored order notes in the database are never modified or overwritten.
    """
    partner = test_setup["partner1"]
    p = test_setup["p1"]

    # Case A: Genuine note mixed with staff metadata, idempotency key, rejection remarks,
    # and exact Flutter generated note 'Placed by Staff for Dealer #123'
    raw_notes_with_meta = (
        "Please pack fragile components with extra foam.\n"
        "[Created by Staff: Vikram SalesStaff (ID: 3)]\n"
        "Placed by Staff for Dealer #123\n"
        "[idempotency_key:550e8400-e29b-41d4-a716-446655440000]\n"
        "[Rejection remarks: Prior rejection resolved]"
    )
    order_a = Order(
        order_number="ORD-NOTES-MIXED-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        notes=raw_notes_with_meta,
        subtotal_before_discount=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("550.00"),
    )
    db_session.add(order_a)
    db_session.flush()

    item_a = OrderItem(
        order_id=order_a.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("550.00"),
        unit_price=Decimal("550.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
    )
    db_session.add(item_a)

    # Case B: Notes contains ONLY internal system metadata including 'Placed by Staff for Dealer #...'
    raw_notes_only_meta = (
        "Placed by Staff for Dealer #456\n"
        "[Created by Staff: Vikram SalesStaff (ID: 3)]\n"
        "[idempotency_key:660e8400-e29b-41d4-a716-446655440000]\n"
        "[Rejection remarks: Needs price check]"
    )
    order_b = Order(
        order_number="ORD-NOTES-META-ONLY-02",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        notes=raw_notes_only_meta,
        subtotal_before_discount=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("550.00"),
    )
    db_session.add(order_b)
    db_session.flush()

    item_b = OrderItem(
        order_id=order_b.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("550.00"),
        unit_price=Decimal("550.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
    )
    db_session.add(item_b)

    # Case C: No notes (notes is None)
    order_c = Order(
        order_number="ORD-NOTES-NONE-03",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        notes=None,
        subtotal_before_discount=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("550.00"),
    )
    db_session.add(order_c)
    db_session.flush()

    item_c = OrderItem(
        order_id=order_c.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("550.00"),
        unit_price=Decimal("550.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
    )
    db_session.add(item_c)

    # Case D: Genuine Staff-entered note with similar words (must be preserved)
    raw_notes_staff_genuine = "Staff note: Deliver to backdoor, Dealer #123 requested urgent delivery"
    order_d = Order(
        order_number="ORD-NOTES-STAFF-GENUINE-04",
        partner_id=partner.id,
        created_by_user_id=test_setup["staff"].id,
        status="pending_approval",
        notes=raw_notes_staff_genuine,
        subtotal_before_discount=Decimal("550.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("550.00"),
    )
    db_session.add(order_d)
    db_session.flush()

    item_d = OrderItem(
        order_id=order_d.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("550.00"),
        unit_price=Decimal("550.00"),
        mrp=Decimal("600.00"),
        list_price=Decimal("550.00"),
    )
    db_session.add(item_d)
    db_session.commit()

    # Verify Case A: Genuine note kept, all metadata stripped
    pdf_a = generate_order_pdf(order_a).decode("latin1", errors="ignore")
    assert "Order Notes:" in pdf_a
    assert "Please pack fragile components with extra foam." in pdf_a
    assert "[Created by Staff" not in pdf_a
    assert "Placed by Staff for Dealer #123" not in pdf_a
    assert "[idempotency_key" not in pdf_a
    assert "[Rejection remarks" not in pdf_a
    # Ensure database note was NOT overwritten or modified
    assert order_a.notes == raw_notes_with_meta

    # Verify Case B: Only metadata -> Order Notes section is omitted
    pdf_b = generate_order_pdf(order_b).decode("latin1", errors="ignore")
    assert "Order Notes" not in pdf_b
    assert "[Created by Staff" not in pdf_b
    assert "Placed by Staff for Dealer" not in pdf_b
    assert "[idempotency_key" not in pdf_b
    assert "[Rejection remarks" not in pdf_b
    assert order_b.notes == raw_notes_only_meta

    # Verify Case C: No notes -> Order Notes section is omitted
    pdf_c = generate_order_pdf(order_c).decode("latin1", errors="ignore")
    assert "Order Notes" not in pdf_c
    assert order_c.notes is None

    # Verify Case D: Genuine staff note with similar words is retained
    pdf_d = generate_order_pdf(order_d).decode("latin1", errors="ignore")
    assert "Order Notes:" in pdf_d
    assert "Staff note: Deliver to backdoor" in pdf_d
    assert order_d.notes == raw_notes_staff_genuine


def test_extract_city_comprehensive() -> None:
    """
    Spec:
    - Handle common Indian address formats (city, state, PIN, country).
    - Remove valid 6-digit Indian PIN codes without corrupting the address.
    - Do not identify a state, country, locality, or district as a city.
    - Do not assume the last address component is the city.
    - Display 'N/A' if city cannot be identified confidently.
    - Verify expected regression table and landmark/road rejection.
    """
    # 1. Expected regression table cases
    assert extract_city_from_address("Pune, Maharashtra, India") == "Pune"
    assert extract_city_from_address("Plot 42, MIDC Bhosari, Pune - 411026") == "Pune"
    assert extract_city_from_address("Ahmedabad - Gujarat") == "Ahmedabad"
    assert extract_city_from_address("Pune Road, Industrial Estate, Maharashtra") == "N/A"
    assert extract_city_from_address("Maharashtra, India") == "N/A"
    assert extract_city_from_address("Unknown Industrial Estate") == "N/A"
    assert extract_city_from_address("New Delhi, India") == "New Delhi"
    assert extract_city_from_address("Navi Mumbai, Maharashtra") == "Navi Mumbai"

    # 2. Road, business name, or landmark containing a city name must NOT be selected
    assert extract_city_from_address("Ahmedabad Highway, Industrial Area, Gujarat") == "N/A"
    assert extract_city_from_address("Pune Sweets, MG Road, Maharashtra") == "N/A"
    assert extract_city_from_address("Jaipur Landmark Opp Temple, Rajasthan") == "N/A"
    assert extract_city_from_address("Delhi Bazar, Main Street, Haryana") == "N/A"

    # 3. Ahmedabad variations
    assert extract_city_from_address("101, Crystal Arcade, CG Road, Navrangpura, Ahmedabad, Gujarat 380009") == "Ahmedabad"
    assert extract_city_from_address("Plot 12, GIDC Vatva, Ahmedabad - 382445, Gujarat, India") == "Ahmedabad"
    assert extract_city_from_address("Ahmedabad - 380001") == "Ahmedabad"
    assert extract_city_from_address("Ahmedabad 380001") == "Ahmedabad"

    # 4. Pune variations
    assert extract_city_from_address("Shop 12, Commercial Complex, MG Road, Shivajinagar, Pune - 411005, Maharashtra, India") == "Pune"
    assert extract_city_from_address("Pune \u2013 411001") == "Pune"  # En-dash
    assert extract_city_from_address("Pune \u2014 411001") == "Pune"  # Em-dash
    assert extract_city_from_address("Pune, Maharashtra") == "Pune"
    assert extract_city_from_address("Pune") == "Pune"

    # 5. Mumbai & Surat variations
    assert extract_city_from_address("Shop 5, Linking Road, Bandra West, Mumbai - 400050, Maharashtra") == "Mumbai"
    assert extract_city_from_address("Shop 12, Link Road\nAndheri West\nMumbai - 400053") == "Mumbai"
    assert extract_city_from_address("Mumbai, Maharashtra, India") == "Mumbai"
    assert extract_city_from_address("Mumbai - 400001") == "Mumbai"
    assert extract_city_from_address("Survey No 102, Near Toll Plaza, Ahmedabad Highway, Surat 395001") == "Surat"

    # 6. New Delhi variations
    assert extract_city_from_address("Flat 302, Connaught Place, New Delhi - 110001") == "New Delhi"
    assert extract_city_from_address("45 Connaught Place, New Delhi 110001") == "New Delhi"
    assert extract_city_from_address("Flat 302, Connaught Place, New Delhi, Delhi - 110001") == "New Delhi"
    assert extract_city_from_address("Connaught Place, New Delhi") == "New Delhi"
    assert extract_city_from_address("Shop 10, GT Road, Delhi") == "Delhi"

    # 7. Other valid cities with PIN codes
    assert extract_city_from_address("MIDC Waluj, Aurangabad - 431136, Maharashtra") == "Aurangabad"
    assert extract_city_from_address("Plot 10, Industrial Area, Surat 395003") == "Surat"
    assert extract_city_from_address("Shop 8, Station Road, Jaipur PIN: 302001, Rajasthan") == "Jaipur"

    # 8. Missing or ambiguous addresses
    assert extract_city_from_address(None) == "N/A"
    assert extract_city_from_address("") == "N/A"
    assert extract_city_from_address("   ") == "N/A"
    assert extract_city_from_address("N/A") == "N/A"
    assert extract_city_from_address("-") == "N/A"
    assert extract_city_from_address("None") == "N/A"
    assert extract_city_from_address("NULL") == "N/A"
    assert extract_city_from_address("Shop 4, Near Bus Stand, Main Road") == "N/A"
    assert extract_city_from_address("Plot 15, Industrial Estate, Sector 4") == "N/A"
    assert extract_city_from_address("Bhandup West, Maharashtra") == "N/A"
    assert extract_city_from_address("Unknown Area, Landmark Opp Temple - 411001") == "N/A"


def test_sales_order_pdf_escaping_special_characters_and_unicode(
    db_session: Session,
) -> None:
    """
    Spec:
    Audit every dynamic string inserted into ReportLab Paragraph markup.
    Escape dynamic text safely, including:
    - Business name
    - Registered address
    - Partner mobile number
    - Partner code
    - Order number
    - Product name
    - Product code/SKU
    - Order status
    - Order notes
    Add tests using values containing &, <, >, quotes, and Unicode characters.
    PDF generation must not fail or interpret user input as ReportLab markup.
    """
    partner = User(
        name='Partner "Alpha" & <Beta>',
        mobile='+91 <9876543210> & "HQ"',
        password_hash=hash_password("pw123"),
        role="partner",
        is_active=True,
    )
    db_session.add(partner)
    db_session.flush()

    prof = PartnerProfile(
        user_id=partner.id,
        business_name='Rajesh & Sons <Automotive> "Speed" \'Pro\' \u20b9',
        business_address='Plot 42 <MIDC>, Bhosari & Chakan, "Sector 5", Pune - 411026',
        partner_code='CODE<PTN>&"1"',
    )
    db_session.add(prof)

    cat = ProductCategory(name="Cables", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code='SKU<999>&"FAST"',
        name='Disc Brake Pad <Set & Springs> "Gold" \'Standard\' \u20b9',
        vehicle_type="2-Wheeler",
        price=Decimal("700.00"),
        list_price=Decimal("650.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    raw_notes = (
        'Handle with care & fragile! <Do not drop>\n'
        '"Second line" with \'quotes\' & \u20b9 symbol'
    )
    order = Order(
        order_number='ORD<2026>&"TEST"',
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        notes=raw_notes,
        subtotal_before_discount=Decimal("650.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("65.00"),
        final_total=Decimal("585.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("650.00"),
        unit_price=Decimal("585.00"),
        mrp=Decimal("700.00"),
        list_price=Decimal("650.00"),
        discount_percentage=Decimal("10.00"),
        discount_amount=Decimal("65.00"),
        discounted_price=Decimal("585.00"),
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    # Must build without throwing xml.parsers.expat.ExpatError or ValueError
    pdf_bytes = generate_order_pdf(order)
    assert len(pdf_bytes) > 1000
    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # Verify key dynamic fields rendered cleanly into PDF stream
    assert "Rajesh & Sons" in pdf_text or "Rajesh &amp; Sons" in pdf_text
    assert "Pune" in pdf_text
    assert "585.00" in pdf_text
    assert "Order Notes:" in pdf_text


def test_sales_order_pdf_footer_layout_separate_columns_long_strings(
    db_session: Session,
) -> None:
    """
    Spec:
    The footer draws:
    - Left: Print Date & Time and City
    - Right: Order number and page number
    Correct layout using separate columns to prevent overlapping.
    Test long city names and long order numbers.
    """
    partner = User(
        name="Long String Partner",
        mobile="9876543299",
        password_hash=hash_password("pw123"),
        role="partner",
        is_active=True,
    )
    db_session.add(partner)
    db_session.flush()

    prof = PartnerProfile(
        user_id=partner.id,
        business_name="Long Name Enterprise Ltd",
        business_address="GIDC Estate, Chhatrapati Sambhajinagar, Maharashtra 431005",
        partner_code="LNG-001",
    )
    db_session.add(prof)

    cat = ProductCategory(name="Spares", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-LONG-01",
        name="Heavy Duty Industrial Assembly Component",
        vehicle_type="3-Wheeler",
        price=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    long_order_num = "ORD-2026-LONG-EXTENDED-PARTNER-BRANCH-MUMBAI-PUNE-CORRIDOR-998877665544332211"
    order = Order(
        order_number=long_order_num,
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("1200.00"),
        discount_percentage=Decimal("0.00"),
        total_discount=Decimal("0.00"),
        final_total=Decimal("1200.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("1200.00"),
        unit_price=Decimal("1200.00"),
        mrp=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    # PDF generation must succeed with the two-column footer table
    pdf_bytes = generate_order_pdf(order)
    assert len(pdf_bytes) > 1000
    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # Verify both long city and long order number exist in the output
    assert "Chhatrapati Sambhajinagar" in pdf_text
    assert "ORD-2026-LONG-EXTENDED" in pdf_text
