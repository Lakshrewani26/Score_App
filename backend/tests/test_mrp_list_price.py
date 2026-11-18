from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import io

import pytest
import reportlab.rl_config
reportlab.rl_config.pageCompression = 0
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
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
    StaffPartnerAssignment,
    StaffProfile,
    User,
)
from app.services.pdf_service import generate_order_pdf

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
            StaffPartnerAssignment.__table__,
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


def _create_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
    password: str = "Secret123!",
    discount_percentage: Decimal = Decimal("0.00"),
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password(password),
        role=role,
        is_active=True,
    )
    db.add(user)
    db.flush()

    if role == "partner":
        profile = PartnerProfile(
            user_id=user.id,
            business_name=f"{name} Store",
            business_address="123 Industrial Area, Pune",
            partner_code=f"PRT-{user.id:04d}",
            discount_percentage=discount_percentage,
        )
        db.add(profile)
    elif role == "staff":
        profile = StaffProfile(
            user_id=user.id,
            staff_id=f"STF-{user.id:04d}",
        )
        db.add(profile)
    elif role == "customer":
        profile = CustomerProfile(
            user_id=user.id,
            state="Maharashtra",
            city="Pune",
        )
        db.add(profile)

    db.commit()
    db.refresh(user)
    return user


def _auth_headers(user: User) -> dict[str, str]:
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
    )
    return {"Authorization": f"Bearer {token}"}


# ==============================================================================
# 1. Database and API Tests
# ==============================================================================

def test_database_accepts_mrp_and_list_price(db_session: Session) -> None:
    cat = ProductCategory(name="Transmission", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-DB-01",
        name="Clutch Plate",
        vehicle_type="2-Wheeler",
        price=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()
    db_session.refresh(p)

    assert p.price == Decimal("1500.00")
    assert p.list_price == Decimal("1200.00")


def test_database_allows_null_list_price(db_session: Session) -> None:
    cat = ProductCategory(name="Brakes", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-NULL-LP",
        name="Brake Shoe",
        vehicle_type="2-Wheeler",
        price=Decimal("800.00"),
        list_price=None,
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()
    db_session.refresh(p)

    assert p.price == Decimal("800.00")
    assert p.list_price is None


def test_negative_list_price_rejected_by_api(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin", mobile="9000000001", role="admin")
    cat = ProductCategory(name="Filters", is_active=True)
    db_session.add(cat)
    db_session.commit()

    headers = _auth_headers(admin)
    payload = {
        "product_code": "PRD-NEG",
        "name": "Negative List Price Product",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": 1000.0,
        "list_price": -50.0,
    }
    resp = client.post("/api/v1/admin/catalogue/products", json=payload, headers=headers)
    assert resp.status_code == 422


def test_more_than_two_decimals_list_price_rejected_by_api(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin", mobile="9000000002", role="admin")
    cat = ProductCategory(name="Engine", is_active=True)
    db_session.add(cat)
    db_session.commit()

    headers = _auth_headers(admin)
    payload = {
        "product_code": "PRD-DEC",
        "name": "Invalid Decimals Product",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": 1000.0,
        "list_price": 500.555,
    }
    resp = client.post("/api/v1/admin/catalogue/products", json=payload, headers=headers)
    assert resp.status_code == 422


def test_admin_can_create_and_update_both_prices(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin", mobile="9000000003", role="admin")
    cat = ProductCategory(name="Lighting", is_active=True)
    db_session.add(cat)
    db_session.commit()

    headers = _auth_headers(admin)

    # 1. Create product with MRP and List Price
    create_payload = {
        "product_code": "PRD-HEADLAMP",
        "name": "LED Headlamp",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": 2500.00,
        "list_price": 2100.00,
    }
    create_resp = client.post("/api/v1/admin/catalogue/products", json=create_payload, headers=headers)
    assert create_resp.status_code == 201
    created_data = create_resp.json()
    assert Decimal(str(created_data["price"])) == Decimal("2500.00")
    assert Decimal(str(created_data["list_price"])) == Decimal("2100.00")
    product_id = created_data["id"]

    # 2. Update both prices
    update_payload = {
        "price": 2700.00,
        "list_price": 2250.00,
    }
    update_resp = client.post(f"/api/v1/admin/catalogue/products/{product_id}/update", json=update_payload, headers=headers)
    assert update_resp.status_code == 200
    updated_data = update_resp.json()
    assert Decimal(str(updated_data["price"])) == Decimal("2700.00")
    assert Decimal(str(updated_data["list_price"])) == Decimal("2250.00")


def test_role_based_catalogue_visibility(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin", mobile="9000000010", role="admin")
    partner = _create_user(db_session, name="Partner", mobile="9000000011", role="partner")
    staff = _create_user(db_session, name="Staff", mobile="9000000012", role="staff")
    customer = _create_user(db_session, name="Customer", mobile="9000000013", role="customer")

    cat = ProductCategory(name="Suspension", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-SHOCK-01",
        name="Rear Shock Absorber",
        vehicle_type="2-Wheeler",
        price=Decimal("1800.00"),
        list_price=Decimal("1400.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    # 1. Partner sees both prices
    partner_resp = client.get("/api/v1/products", headers=_auth_headers(partner))
    assert partner_resp.status_code == 200
    partner_items = partner_resp.json()["items"]
    assert len(partner_items) == 1
    assert Decimal(str(partner_items[0]["price"])) == Decimal("1800.00")
    assert Decimal(str(partner_items[0]["list_price"])) == Decimal("1400.00")

    # 2. Staff sees both prices
    staff_resp = client.get("/api/v1/products", headers=_auth_headers(staff))
    assert staff_resp.status_code == 200
    staff_items = staff_resp.json()["items"]
    assert Decimal(str(staff_items[0]["price"])) == Decimal("1800.00")
    assert Decimal(str(staff_items[0]["list_price"])) == Decimal("1400.00")

    # 3. Admin sees both prices on shared catalogue
    admin_resp = client.get("/api/v1/products", headers=_auth_headers(admin))
    assert admin_resp.status_code == 200
    admin_items = admin_resp.json()["items"]
    assert Decimal(str(admin_items[0]["price"])) == Decimal("1800.00")
    assert Decimal(str(admin_items[0]["list_price"])) == Decimal("1400.00")

    # 4. Customer sees MRP only (list_price is not exposed)
    customer_resp = client.get("/api/v1/products", headers=_auth_headers(customer))
    assert customer_resp.status_code == 200
    customer_items = customer_resp.json()["items"]
    assert Decimal(str(customer_items[0]["price"])) == Decimal("1800.00")
    assert customer_items[0].get("list_price") is None
    assert "list_price" not in customer_items[0]

    # 5. Unauthenticated request sees MRP only (list_price is not exposed)
    unauth_resp = client.get("/api/v1/products")
    assert unauth_resp.status_code == 200
    unauth_items = unauth_resp.json()["items"]
    assert Decimal(str(unauth_items[0]["price"])) == Decimal("1800.00")
    assert unauth_items[0].get("list_price") is None
    assert "list_price" not in unauth_items[0]


# ==============================================================================
# 2. Pricing and Order Calculation Tests
# ==============================================================================

def test_order_calculation_uses_list_price_when_available(client: TestClient, db_session: Session) -> None:
    # Example from spec:
    # MRP: 1,500
    # List Price: 1,200
    # Discount: 10%
    # Discount Amount: 120
    # Final Amount: 1,080
    partner = _create_user(
        db_session,
        name="Rajesh Auto",
        mobile="9111111111",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    cat = ProductCategory(name="Engine", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-SPEC-01",
        name="Spec Piston Kit",
        vehicle_type="2-Wheeler",
        price=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    headers = _auth_headers(partner)

    # 1. Preview calculation
    preview_resp = client.post(
        "/api/v1/orders/preview",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert preview_resp.status_code == 200
    preview_data = preview_resp.json()
    item = preview_data["items"][0]
    assert Decimal(str(item["mrp"])) == Decimal("1500.00")
    assert Decimal(str(item["list_price"])) == Decimal("1200.00")
    assert Decimal(str(item["original_price"])) == Decimal("1200.00")  # calculation price
    assert Decimal(str(item["discount_percentage"])) == Decimal("10.00")
    assert Decimal(str(item["discount_amount"])) == Decimal("120.00")
    assert Decimal(str(item["unit_price"])) == Decimal("1080.00")
    assert Decimal(str(item["subtotal"])) == Decimal("1080.00")
    assert Decimal(str(preview_data["subtotal_before_discount"])) == Decimal("1200.00")
    assert Decimal(str(preview_data["total_discount"])) == Decimal("120.00")
    assert Decimal(str(preview_data["final_total"])) == Decimal("1080.00")

    # 2. Order creation
    order_resp = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert order_resp.status_code == 201
    order_data = order_resp.json()
    saved_item = order_data["items"][0]
    assert Decimal(str(saved_item["mrp"])) == Decimal("1500.00")
    assert Decimal(str(saved_item["list_price"])) == Decimal("1200.00")
    assert Decimal(str(saved_item["original_price"])) == Decimal("1200.00")
    assert Decimal(str(saved_item["discount_amount"])) == Decimal("120.00")
    assert Decimal(str(saved_item["unit_price"])) == Decimal("1080.00")
    assert Decimal(str(order_data["final_total"])) == Decimal("1080.00")


def test_order_calculation_falls_back_to_mrp_when_list_price_is_null(client: TestClient, db_session: Session) -> None:
    partner = _create_user(
        db_session,
        name="Fallback Auto",
        mobile="9111111112",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    cat = ProductCategory(name="Engine", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-NULL-LP-CALC",
        name="Legacy Gasket Set",
        vehicle_type="2-Wheeler",
        price=Decimal("1500.00"),
        list_price=None,
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    headers = _auth_headers(partner)

    order_resp = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert order_resp.status_code == 201
    order_data = order_resp.json()
    saved_item = order_data["items"][0]
    assert Decimal(str(saved_item["mrp"])) == Decimal("1500.00")
    assert saved_item["list_price"] is None
    assert Decimal(str(saved_item["original_price"])) == Decimal("1500.00")  # fallback to MRP
    assert Decimal(str(saved_item["discount_amount"])) == Decimal("150.00")
    assert Decimal(str(saved_item["unit_price"])) == Decimal("1350.00")
    assert Decimal(str(order_data["final_total"])) == Decimal("1350.00")


def test_staff_order_creation_calculates_consistently(client: TestClient, db_session: Session) -> None:
    partner = _create_user(
        db_session,
        name="Partner Dealer",
        mobile="9222222221",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    staff = _create_user(
        db_session,
        name="Sales Officer",
        mobile="9222222222",
        role="staff",
    )
    # Assign staff to partner
    assignment = StaffPartnerAssignment(
        staff_id=staff.id,
        partner_id=partner.id,
        is_active=True,
    )
    db_session.add(assignment)

    cat = ProductCategory(name="Electrical", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-STAFF-LP",
        name="Starter Motor",
        vehicle_type="2-Wheeler",
        price=Decimal("2000.00"),
        list_price=Decimal("1600.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    staff_headers = _auth_headers(staff)
    staff_order_payload = {
        "partner_id": partner.id,
        "items": [{"product_id": p.id, "quantity": 2}],
    }
    resp = client.post("/api/v1/staff/orders", json=staff_order_payload, headers=staff_headers)
    assert resp.status_code == 201
    order_data = resp.json()

    # Calculation price is 1600 * 2 = 3200
    # Discount is 10% = 320 (160 per unit)
    # Discounted price is 1440 per unit
    # Final total is 2880
    saved_item = order_data["items"][0]
    assert Decimal(str(saved_item["mrp"])) == Decimal("2000.00")
    assert Decimal(str(saved_item["list_price"])) == Decimal("1600.00")
    assert Decimal(str(saved_item["original_price"])) == Decimal("1600.00")
    assert Decimal(str(saved_item["discount_percentage"])) == Decimal("10.00")
    assert Decimal(str(saved_item["discount_amount"])) == Decimal("160.00")
    assert Decimal(str(saved_item["unit_price"])) == Decimal("1440.00")
    assert Decimal(str(saved_item["subtotal"])) == Decimal("2880.00")
    assert Decimal(str(order_data["final_total"])) == Decimal("2880.00")


# ==============================================================================
# 3. Historical Order Snapshots and PDF Invoice Tests
# ==============================================================================

def test_price_updates_do_not_alter_historical_orders_or_pdf(client: TestClient, db_session: Session) -> None:
    partner = _create_user(
        db_session,
        name="Historical Partner",
        mobile="9333333331",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    admin = _create_user(db_session, name="Admin", mobile="9333333332", role="admin")

    cat = ProductCategory(name="Brake Parts", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-HIST-01",
        name="Ceramic Disc Brake",
        vehicle_type="2-Wheeler",
        price=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    # Partner creates order
    partner_headers = _auth_headers(partner)
    order_resp = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=partner_headers,
    )
    assert order_resp.status_code == 201
    order_id = order_resp.json()["id"]

    # Admin changes product prices drastically
    admin_headers = _auth_headers(admin)
    update_resp = client.post(
        f"/api/v1/admin/catalogue/products/{p.id}/update",
        json={"price": 3000.00, "list_price": 2500.00},
        headers=admin_headers,
    )
    assert update_resp.status_code == 200

    # Fetch original order detail: amounts must NOT change!
    order_detail_resp = client.get(f"/api/v1/orders/{order_id}", headers=partner_headers)
    assert order_detail_resp.status_code == 200
    order_detail = order_detail_resp.json()

    saved_item = order_detail["items"][0]
    assert Decimal(str(saved_item["mrp"])) == Decimal("1500.00")
    assert Decimal(str(saved_item["list_price"])) == Decimal("1200.00")
    assert Decimal(str(saved_item["original_price"])) == Decimal("1200.00")
    assert Decimal(str(saved_item["discount_amount"])) == Decimal("120.00")
    assert Decimal(str(saved_item["unit_price"])) == Decimal("1080.00")
    assert Decimal(str(order_detail["final_total"])) == Decimal("1080.00")

    # Generate PDF invoice and ensure it builds correctly using saved snapshots
    db_order = db_session.query(Order).filter(Order.id == order_id).first()
    assert db_order is not None

    pdf_bytes = generate_order_pdf(db_order)
    assert isinstance(pdf_bytes, bytes)
    assert len(pdf_bytes) > 0
    # PDF starts with %PDF magic header
    assert pdf_bytes.startswith(b"%PDF")


def test_historical_order_with_null_mrp_snapshot_handling(client: TestClient, db_session: Session) -> None:
    partner = _create_user(
        db_session,
        name="Legacy Partner",
        mobile="9444444441",
        role="partner",
        discount_percentage=Decimal("5.00"),
    )
    cat = ProductCategory(name="Cables", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-LEGACY-01",
        name="Clutch Cable",
        vehicle_type="2-Wheeler",
        price=Decimal("400.00"),
        list_price=None,
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    # Create historical order directly in database with mrp=None and list_price=None (pre-migration state)
    order = Order(
        order_number="ORD-HIST-001",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("800.00"),
        discount_percentage=Decimal("5.00"),
        total_discount=Decimal("40.00"),
        final_total=Decimal("760.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=2,
        original_price=Decimal("400.00"),
        discount_percentage=Decimal("5.00"),
        discount_amount=Decimal("20.00"),
        discounted_price=Decimal("380.00"),
        unit_price=Decimal("380.00"),
        mrp=None,         # pre-migration NULL
        list_price=None,  # pre-migration NULL
    )
    db_session.add(item)
    db_session.commit()

    partner_headers = _auth_headers(partner)
    order_detail_resp = client.get(f"/api/v1/orders/{order.id}", headers=partner_headers)
    assert order_detail_resp.status_code == 200
    order_detail = order_detail_resp.json()

    saved_item = order_detail["items"][0]
    # In pre-migration state when mrp is NULL, API preserves NULL and does not fabricate MRP
    assert saved_item["mrp"] is None
    assert saved_item["list_price"] is None
    assert Decimal(str(saved_item["original_price"])) == Decimal("400.00")
    assert Decimal(str(saved_item["unit_price"])) == Decimal("380.00")
    assert Decimal(str(order_detail["final_total"])) == Decimal("760.00")

    # Generate PDF invoice and ensure legacy null-mrp order renders cleanly
    db_session.refresh(order)
    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    # Test migration backfill e6f7a8b9c0d1:
    # Safely backfills historical order_items.mrp from original_price / unit_price
    # Does not overwrite non-NULL snapshots, does not infer list_price.
    item_with_snapshots = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("450.00"),
        unit_price=Decimal("450.00"),
        mrp=Decimal("500.00"),
        list_price=Decimal("450.00"),
    )
    db_session.add(item_with_snapshots)
    db_session.commit()

    from sqlalchemy import text
    db_session.execute(
        text(
            "UPDATE order_items "
            "SET mrp = original_price "
            "WHERE mrp IS NULL "
            "  AND original_price IS NOT NULL"
        )
    )
    db_session.commit()

    db_session.refresh(item)
    db_session.refresh(item_with_snapshots)

    # Legacy item mrp backfilled safely from original_price snapshot
    assert item.mrp == Decimal("400.00")
    assert item.list_price is None

    # Existing snapshots are preserved (not overwritten)
    assert item_with_snapshots.mrp == Decimal("500.00")
    assert item_with_snapshots.list_price == Decimal("450.00")

    # After backfill, detail endpoint returns the backfilled MRP snapshot
    order_detail_resp2 = client.get(f"/api/v1/orders/{order.id}", headers=partner_headers)
    assert order_detail_resp2.status_code == 200
    detail2 = order_detail_resp2.json()
    assert Decimal(str(detail2["items"][0]["mrp"])) == Decimal("400.00")


# ==============================================================================
# 5. Targeted Tests: Mandatory List Price on Creation & Updates
# ==============================================================================

def test_admin_create_product_requires_list_price_validation(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin Validator", mobile="9111111101", role="admin")
    cat = ProductCategory(name="Electrical", is_active=True)
    db_session.add(cat)
    db_session.commit()

    headers = _auth_headers(admin)

    # 1. Omitting list_price returns HTTP 422
    missing_lp_payload = {
        "product_code": "ELEC-001",
        "name": "Ignition Coil",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": 850.00,
    }
    resp1 = client.post("/api/v1/admin/catalogue/products", json=missing_lp_payload, headers=headers)
    assert resp1.status_code == 422

    # 2. Sending list_price as null returns HTTP 422
    null_lp_payload = {
        "product_code": "ELEC-002",
        "name": "Spark Plug Cable",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": 350.00,
        "list_price": None,
    }
    resp2 = client.post("/api/v1/admin/catalogue/products", json=null_lp_payload, headers=headers)
    assert resp2.status_code == 422

    # 3. Sending valid list_price succeeds (HTTP 201)
    valid_payload = {
        "product_code": "ELEC-003",
        "name": "Headlight Relay",
        "category_id": cat.id,
        "vehicle_type": "2-Wheeler",
        "price": 450.00,
        "list_price": 380.00,
    }
    resp3 = client.post("/api/v1/admin/catalogue/products", json=valid_payload, headers=headers)
    assert resp3.status_code == 201
    created = resp3.json()
    assert Decimal(str(created["price"])) == Decimal("450.00")
    assert Decimal(str(created["list_price"])) == Decimal("380.00")
    prod_id = created["id"]

    # 4. Updating product without specifying list_price preserves existing list_price
    resp4 = client.post(
        f"/api/v1/admin/catalogue/products/{prod_id}/update",
        json={"name": "Headlight Relay V2"},
        headers=headers,
    )
    assert resp4.status_code == 200
    updated = resp4.json()
    assert updated["name"] == "Headlight Relay V2"
    assert Decimal(str(updated["list_price"])) == Decimal("380.00")

    # 5. Clearing list_price explicitly to null is supported on update
    resp5 = client.post(
        f"/api/v1/admin/catalogue/products/{prod_id}/update",
        json={"list_price": None},
        headers=headers,
    )
    assert resp5.status_code == 200
    cleared = resp5.json()
    assert cleared["list_price"] is None


# ==============================================================================
# 6. Targeted Tests: Optional Authentication Dependency Behavior
# ==============================================================================

def test_optional_auth_no_token_returns_public_access(client: TestClient, db_session: Session) -> None:
    cat = ProductCategory(name="Tyres", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="TYR-001",
        name="Tubeless Front Tyre",
        vehicle_type="2-Wheeler",
        price=Decimal("1800.00"),
        list_price=Decimal("1500.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    # Public request with no Authorization header
    resp = client.get("/api/v1/products")
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) >= 1
    # Public catalogue hides list_price
    tyre = next(item for item in items if item["product_code"] == "TYR-001")
    assert tyre.get("list_price") is None
    assert Decimal(str(tyre["price"])) == Decimal("1800.00")


def test_optional_auth_valid_active_user_returns_user(client: TestClient, db_session: Session) -> None:
    partner = _create_user(db_session, name="Active Partner", mobile="9111111102", role="partner")
    cat = ProductCategory(name="Batteries", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="BAT-001",
        name="12V Maintenance Free Battery",
        vehicle_type="2-Wheeler",
        price=Decimal("2200.00"),
        list_price=Decimal("1850.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    resp = client.get("/api/v1/products", headers=_auth_headers(partner))
    assert resp.status_code == 200
    items = resp.json()["items"]
    battery = next(item for item in items if item["product_code"] == "BAT-001")
    # Partner sees list_price
    assert Decimal(str(battery["list_price"])) == Decimal("1850.00")
    assert Decimal(str(battery["price"])) == Decimal("2200.00")


def test_optional_auth_invalid_token_returns_401(client: TestClient) -> None:
    resp = client.get(
        "/api/v1/products",
        headers={"Authorization": "Bearer invalid.token.value"},
    )
    assert resp.status_code == 401
    assert "Invalid authentication token" in resp.json()["detail"]


def test_optional_auth_expired_token_returns_401(client: TestClient, db_session: Session) -> None:
    partner = _create_user(db_session, name="Expired Partner", mobile="9111111103", role="partner")
    expired_token = create_access_token(
        subject=str(partner.id),
        role=partner.role,
        mobile=partner.mobile,
        expires_delta=timedelta(seconds=-10),
    )
    resp = client.get(
        "/api/v1/products",
        headers={"Authorization": f"Bearer {expired_token}"},
    )
    assert resp.status_code == 401
    assert "expired" in resp.json()["detail"].lower()


def test_optional_auth_inactive_user_token_returns_401(client: TestClient, db_session: Session) -> None:
    inactive_user = _create_user(db_session, name="Inactive Partner", mobile="9111111104", role="partner")
    inactive_user.is_active = False
    db_session.commit()

    resp = client.get(
        "/api/v1/products",
        headers=_auth_headers(inactive_user),
    )
    assert resp.status_code == 401
    assert "inactive" in resp.json()["detail"].lower()


def test_optional_auth_missing_user_token_returns_401(client: TestClient) -> None:
    # Token for a user ID that does not exist in DB
    ghost_token = create_access_token(
        subject="999999",
        role="partner",
        mobile="9111111199",
    )
    resp = client.get(
        "/api/v1/products",
        headers={"Authorization": f"Bearer {ghost_token}"},
    )
    assert resp.status_code == 401
    assert "no longer exists" in resp.json()["detail"].lower()


# ==============================================================================
# 7. Targeted Tests: PDF Invoice Totals Layout & Text Extraction
# ==============================================================================

def test_pdf_invoice_totals_layout_and_text_extraction_with_explicit_list_price(db_session: Session) -> None:
    """
    Verify 9-column PDF invoice layout with populated List Price:
    Extracts text to ensure MRP, List Price, Discount %, Discount Amount,
    Subtotal, and Final Order Total are present and properly formatted.
    """
    reportlab.rl_config.pageCompression = 0

    partner = _create_user(
        db_session,
        name="Apex Motors",
        mobile="9888888801",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    cat = ProductCategory(name="Brakes", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="BRK-APEX-01",
        name="Ceramic Disc Brake Pads",
        vehicle_type="2-Wheeler",
        price=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    # Order calculation:
    # MRP: 1,500.00
    # List Price: 1,200.00
    # Qty: 2
    # Subtotal Before Discount: 2 * 1,200.00 = 2,400.00
    # Discount: 10% on 1,200.00 = 120.00 per unit -> Total Discount = 240.00
    # Final Price per unit: 1,080.00 -> Line Total: 2,160.00
    # Final Order Total: 2,160.00
    order = Order(
        order_number="ORD-PDF-TEST-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("2400.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("240.00"),
        final_total=Decimal("2160.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=2,
        original_price=Decimal("1200.00"),
        discount_percentage=Decimal("10.00"),
        discount_amount=Decimal("120.00"),
        discounted_price=Decimal("1080.00"),
        unit_price=Decimal("1080.00"),
        mrp=Decimal("1500.00"),
        list_price=Decimal("1200.00"),
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # 1. Product identification in invoice
    assert "Apex Motors" in pdf_text
    assert "ORD-PDF-TEST-01" in pdf_text

    # 2. MRP (Rs. 1,500.00)
    assert "1,500.00" in pdf_text

    # 3. List Price (Rs. 1,200.00) - explicitly entered, NOT fallback
    assert "1,200.00" in pdf_text
    assert "MRP fallback" not in pdf_text

    # 4. Discount percentage (10.0%) and Discount amount (120.00 per unit, 240.00 total)
    assert "10.0%" in pdf_text
    assert "120.00" in pdf_text
    assert "240.00" in pdf_text

    # 5. Final unit price (1,080.00) and line total (2,160.00)
    assert "1,080.00" in pdf_text
    assert "2,160.00" in pdf_text

    # 6. Subtotal Before Discount and Final Order Total rows
    assert "Subtotal Before Discount:" in pdf_text
    assert "2,400.00" in pdf_text
    assert "Final Order Total:" in pdf_text


def test_pdf_invoice_totals_layout_and_text_extraction_with_mrp_fallback(db_session: Session) -> None:
    """
    Verify 9-column PDF invoice layout when List Price is NULL:
    Preserves distinction between actual List Price snapshot and effective calculation price
    by explicitly marking '(MRP fallback)'.
    Extracts text to ensure MRP, fallback List Price, Discount %, Discount Amount,
    Subtotal, and Final Order Total are present and properly formatted.
    """
    reportlab.rl_config.pageCompression = 0

    partner = _create_user(
        db_session,
        name="Metro Spares",
        mobile="9888888802",
        role="partner",
        discount_percentage=Decimal("15.00"),
    )
    cat = ProductCategory(name="Transmission", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="TRN-METRO-01",
        name="Drive Chain Kit",
        vehicle_type="2-Wheeler",
        price=Decimal("1600.00"),
        list_price=None,  # Null list price: MRP fallback!
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    # Order calculation:
    # Calculation price falls back to MRP: 1,600.00
    # Qty: 1
    # Subtotal Before Discount: 1,600.00
    # Discount: 15% on 1,600.00 = 240.00
    # Final Price per unit / Line Total: 1,360.00
    # Final Order Total: 1,360.00
    order = Order(
        order_number="ORD-PDF-FALLBACK-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("1600.00"),
        discount_percentage=Decimal("15.00"),
        total_discount=Decimal("240.00"),
        final_total=Decimal("1360.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("1600.00"),
        discount_percentage=Decimal("15.00"),
        discount_amount=Decimal("240.00"),
        discounted_price=Decimal("1360.00"),
        unit_price=Decimal("1360.00"),
        mrp=Decimal("1600.00"),
        list_price=None,  # Null snapshot
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # 1. Product identification in invoice
    assert "Metro Spares" in pdf_text
    assert "ORD-PDF-FALLBACK-01" in pdf_text

    # 2. MRP (1,600.00)
    assert "1,600.00" in pdf_text

    # 3. List Price indicates MRP fallback clearly to preserve distinction
    assert "MRP fallback" in pdf_text
    assert "Temporary MRP fallback" in pdf_text

    # 4. Discount percentage (15.0%) and Discount amount (240.00)
    assert "15.0%" in pdf_text
    assert "240.00" in pdf_text

    # 5. Unit price (1,360.00) and Subtotal / Final Order Total
    assert "1,360.00" in pdf_text
    assert "Subtotal Before Discount:" in pdf_text
    assert "Final Order Total:" in pdf_text


# ==============================================================================
# 7. Targeted Regression Tests: Strict Scope Fixes
# ==============================================================================

def test_order_creation_with_null_mrp_and_list_price_present(client: TestClient, db_session: Session) -> None:
    """
    Spec: Product with MRP NULL and List Price ₹1,200.
    - Order calculation uses List Price.
    - Stored MRP snapshot remains NULL.
    - Stored List Price snapshot is ₹1,200.
    """
    partner = _create_user(
        db_session,
        name="Null MRP Dealer",
        mobile="9333333301",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    cat = ProductCategory(name="Suspension", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-NULL-MRP-01",
        name="Front Fork Bushing",
        vehicle_type="2-Wheeler",
        price=None,  # MRP NULL
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    headers = _auth_headers(partner)

    # 1. Preview order
    preview_resp = client.post(
        "/api/v1/orders/preview",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert preview_resp.status_code == 200
    preview_data = preview_resp.json()
    item_prev = preview_data["items"][0]
    assert item_prev["mrp"] is None
    assert Decimal(str(item_prev["list_price"])) == Decimal("1200.00")
    assert Decimal(str(item_prev["original_price"])) == Decimal("1200.00")
    assert Decimal(str(item_prev["unit_price"])) == Decimal("1080.00")
    assert Decimal(str(preview_data["final_total"])) == Decimal("1080.00")

    # 2. Place order
    order_resp = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert order_resp.status_code == 201
    order_data = order_resp.json()
    saved_item = order_data["items"][0]

    # Stored and returned MRP snapshot remains NULL
    assert saved_item["mrp"] is None
    # Stored and returned List Price snapshot is 1,200.00
    assert Decimal(str(saved_item["list_price"])) == Decimal("1200.00")
    # Calculation price is List Price
    assert Decimal(str(saved_item["original_price"])) == Decimal("1200.00")
    assert Decimal(str(saved_item["unit_price"])) == Decimal("1080.00")
    assert Decimal(str(order_data["final_total"])) == Decimal("1080.00")

    # Verify directly in DB
    db_item = db_session.get(OrderItem, saved_item["id"])
    assert db_item is not None
    assert db_item.mrp is None
    assert db_item.list_price == Decimal("1200.00")
    assert db_item.original_price == Decimal("1200.00")
    assert db_item.unit_price == Decimal("1080.00")


def test_order_creation_fails_when_both_mrp_and_list_price_null(client: TestClient, db_session: Session) -> None:
    """
    Spec: Product with both MRP and List Price NULL.
    - Existing validation behavior is preserved.
    - No fabricated price is stored.
    """
    partner = _create_user(
        db_session,
        name="No Price Partner",
        mobile="9333333302",
        role="partner",
        discount_percentage=Decimal("5.00"),
    )
    cat = ProductCategory(name="Gears", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-NO-PRICE-01",
        name="Unpriced Gear",
        vehicle_type="2-Wheeler",
        price=None,
        list_price=None,
        is_active=True,
    )
    db_session.add(p)
    db_session.commit()

    headers = _auth_headers(partner)

    # Preview rejects unpriced product
    prev_resp = client.post(
        "/api/v1/orders/preview",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert prev_resp.status_code == 422
    assert "does not have an authorized price" in prev_resp.json()["detail"]

    # Place order rejects unpriced product
    order_resp = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p.id, "quantity": 1}]},
        headers=headers,
    )
    assert order_resp.status_code == 422
    assert "has no valid price" in order_resp.json()["detail"]

    # Ensure no order or order items were created
    orders_count = db_session.query(Order).count()
    assert orders_count == 0


def test_pdf_invoice_with_null_mrp_does_not_label_list_price_as_mrp(db_session: Session) -> None:
    """
    Spec: PDF with MRP NULL and List Price present.
    - PDF does not label List Price as MRP.
    - MRP column displays '-' or 'Not set', not List Price.
    - List Price displays explicit list price without fallback indicator.
    """
    partner = _create_user(
        db_session,
        name="Quality Spares",
        mobile="9333333303",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    cat = ProductCategory(name="Bearings", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="BRG-NULL-MRP",
        name="Wheel Ball Bearing",
        vehicle_type="2-Wheeler",
        price=None,  # NULL MRP
        list_price=Decimal("1200.00"),
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    order = Order(
        order_number="ORD-PDF-NULL-MRP-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("1200.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("120.00"),
        final_total=Decimal("1080.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("1200.00"),
        discount_percentage=Decimal("10.00"),
        discount_amount=Decimal("120.00"),
        discounted_price=Decimal("1080.00"),
        unit_price=Decimal("1080.00"),
        mrp=None,  # Actual MRP is NULL
        list_price=Decimal("1200.00"),
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # List price is present
    assert "1,200.00" in pdf_text
    # Explicit list price is used, so no fallback indicator
    assert "Temporary MRP fallback" not in pdf_text
    assert "MRP fallback" not in pdf_text
    # Final price
    assert "1,080.00" in pdf_text


def test_pdf_invoice_with_both_mrp_and_list_price_null_does_not_label_as_fallback(db_session: Session) -> None:
    """
    Spec: PDF with both MRP and List Price NULL.
    - PDF does not label it as a temporary MRP fallback.
    - Does not use original_price or unit_price to invent an MRP fallback label.
    - Footnote explaining MRP fallback does not appear when no items use MRP fallback.
    - Preserves totals and line calculations.
    """
    partner = _create_user(
        db_session,
        name="Both Null Spares",
        mobile="9333333304",
        role="partner",
        discount_percentage=Decimal("10.00"),
    )
    cat = ProductCategory(name="Accessories", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="ACC-BOTH-NULL",
        name="Handle Grip Set",
        vehicle_type="2-Wheeler",
        price=None,
        list_price=None,
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    order = Order(
        order_number="ORD-PDF-BOTH-NULL-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("500.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("50.00"),
        final_total=Decimal("450.00"),
    )
    db_session.add(order)
    db_session.flush()

    item = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("500.00"),
        discount_percentage=Decimal("10.00"),
        discount_amount=Decimal("50.00"),
        discounted_price=Decimal("450.00"),
        unit_price=Decimal("450.00"),
        mrp=None,         # Both NULL
        list_price=None,  # Both NULL
    )
    db_session.add(item)
    db_session.commit()
    db_session.refresh(order)

    pdf_bytes = generate_order_pdf(order)
    assert isinstance(pdf_bytes, bytes)
    assert pdf_bytes.startswith(b"%PDF")

    pdf_text = pdf_bytes.decode("latin1", errors="ignore")

    # Does NOT label the item as MRP fallback when both are NULL
    assert "Temporary MRP fallback" not in pdf_text
    assert "MRP fallback" not in pdf_text
    assert "Note: Items marked with" not in pdf_text

    # Preserves totals and line calculations
    assert "ORD-PDF-BOTH-NULL-01" in pdf_text
    assert "450.00" in pdf_text
    assert "500.00" in pdf_text


def test_migration_e6f7a8b9c0d1_backfill_safety(db_session: Session) -> None:
    """
    Focused migration safety test for e6f7a8b9c0d1 backfill:
    - A reliable historical original_price is copied into MRP.
    - Missing original_price leaves MRP NULL.
    - Historical List Price remains NULL.
    - unit_price is never copied into MRP (avoids copying final discounted price).
    - Existing non-NULL snapshots are never overwritten.
    """
    partner = _create_user(
        db_session,
        name="Backfill Test Partner",
        mobile="9555555551",
        role="partner",
    )
    cat = ProductCategory(name="Ignition", is_active=True)
    db_session.add(cat)
    db_session.flush()

    p = Product(
        category_id=cat.id,
        product_code="PRD-IGN-01",
        name="Ignition Coil",
        vehicle_type="2-Wheeler",
        price=Decimal("600.00"),
        list_price=None,
        is_active=True,
    )
    db_session.add(p)
    db_session.flush()

    order = Order(
        order_number="ORD-MIG-TEST-01",
        partner_id=partner.id,
        created_by_user_id=partner.id,
        status="pending_approval",
        subtotal_before_discount=Decimal("1200.00"),
        discount_percentage=Decimal("10.00"),
        total_discount=Decimal("120.00"),
        final_total=Decimal("1080.00"),
    )
    db_session.add(order)
    db_session.flush()

    # Item 1: Reliable historical original_price present (MRP was 600.00, discounted unit_price is 540.00)
    item_reliable = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("600.00"),
        unit_price=Decimal("540.00"),
        mrp=None,
        list_price=None,
    )
    # Item 2: Missing original_price, unit_price present (discounted 450.00)
    item_missing_orig = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=None,
        unit_price=Decimal("450.00"),
        mrp=None,
        list_price=None,
    )
    # Item 3: Existing non-NULL snapshots (mrp=700.00, list_price=650.00)
    item_existing_snapshots = OrderItem(
        order_id=order.id,
        product_id=p.id,
        quantity=1,
        original_price=Decimal("650.00"),
        unit_price=Decimal("650.00"),
        mrp=Decimal("700.00"),
        list_price=Decimal("650.00"),
    )
    db_session.add_all([item_reliable, item_missing_orig, item_existing_snapshots])
    db_session.commit()

    # Execute exact migration e6f7a8b9c0d1 backfill SQL
    from sqlalchemy import text
    db_session.execute(
        text(
            "UPDATE order_items "
            "SET mrp = original_price "
            "WHERE mrp IS NULL "
            "  AND original_price IS NOT NULL"
        )
    )
    db_session.commit()

    db_session.refresh(item_reliable)
    db_session.refresh(item_missing_orig)
    db_session.refresh(item_existing_snapshots)

    # 1. Reliable original_price copied into MRP
    assert item_reliable.mrp == Decimal("600.00")
    # 2. Historical List Price remains NULL
    assert item_reliable.list_price is None

    # 3. Missing original_price leaves MRP NULL
    assert item_missing_orig.mrp is None
    # 4. unit_price is never copied into MRP
    assert item_missing_orig.mrp != item_missing_orig.unit_price
    assert item_missing_orig.list_price is None

    # 5. Existing non-NULL snapshots are untouched
    assert item_existing_snapshots.mrp == Decimal("700.00")
    assert item_existing_snapshots.list_price == Decimal("650.00")
