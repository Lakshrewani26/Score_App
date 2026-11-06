from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
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
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    User,
    Zone,
)

TEST_SECRET = "test-secret-key-score-app-admin-panel-minimum-32-chars-long"


@pytest.fixture(autouse=True)
def configure_test_jwt(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "jwt_secret_key", TEST_SECRET)
    monkeypatch.setattr(settings, "jwt_algorithm", "HS256")
    monkeypatch.setattr(settings, "jwt_access_token_expire_minutes", 60)


@pytest.fixture
def enhancement_db_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture
def client(enhancement_db_engine):
    def override_get_db():
        with Session(enhancement_db_engine) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


def _admin_token(user_id: int = 1) -> str:
    return create_access_token(
        subject=str(user_id),
        role="admin",
        mobile="9999999999",
    )


def _partner_token(user_id: int) -> str:
    return create_access_token(
        subject=str(user_id),
        role="partner",
        mobile="9888888888",
    )


def _seed_admin(engine) -> User:
    with Session(engine) as session:
        admin = User(
            name="Super Admin",
            mobile="9999999999",
            password_hash=hash_password("admin_pass_123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)
        session.commit()
        session.refresh(admin)
        return admin


# =============================================================================
# 1. Zone Management Tests
# =============================================================================

def test_zone_crud_and_status(enhancement_db_engine, client):
    _seed_admin(enhancement_db_engine)
    headers = {"Authorization": f"Bearer {_admin_token()}"}

    # 1. List zones (initially empty)
    res = client.get("/api/v1/admin/zones", headers=headers)
    assert res.status_code == 200
    assert res.json()["total"] == 0

    # 2. Create Zone
    create_res = client.post(
        "/api/v1/admin/zones",
        headers=headers,
        json={"name": "North Zone", "description": "Northern district"},
    )
    assert create_res.status_code == 201
    zone_data = create_res.json()
    assert zone_data["name"] == "North Zone"
    assert zone_data["is_active"] is True
    zone_id = zone_data["id"]

    # 3. Duplicate name rejected with 409
    dup_res = client.post(
        "/api/v1/admin/zones",
        headers=headers,
        json={"name": "north zone"},  # case-insensitive
    )
    assert dup_res.status_code == 409

    # 4. Get zone detail
    detail_res = client.get(f"/api/v1/admin/zones/{zone_id}", headers=headers)
    assert detail_res.status_code == 200
    assert detail_res.json()["name"] == "North Zone"

    # 5. Update zone
    update_res = client.patch(
        f"/api/v1/admin/zones/{zone_id}",
        headers=headers,
        json={"name": "North Zone Updated", "description": "Updated desc"},
    )
    assert update_res.status_code == 200
    assert update_res.json()["name"] == "North Zone Updated"

    # 6. Deactivate zone
    status_res = client.post(
        f"/api/v1/admin/zones/{zone_id}/status",
        headers=headers,
        json={"is_active": False},
    )
    assert status_res.status_code == 200
    assert status_res.json()["is_active"] is False


# =============================================================================
# 2. Customer Creation & Management by Admin
# =============================================================================

def test_admin_create_customer(enhancement_db_engine, client):
    _seed_admin(enhancement_db_engine)
    headers = {"Authorization": f"Bearer {_admin_token()}"}

    cust_payload = {
        "name": "Jane Customer",
        "mobile": "9123456780",
        "password": "customer_pass_123",
        "state": "Maharashtra",
        "city": "Pune",
        "segment": "Automotive",
    }
    res = client.post("/api/v1/admin/users/customers", headers=headers, json=cust_payload)
    assert res.status_code == 201
    data = res.json()
    assert data["name"] == "Jane Customer"
    assert data["role"] == "customer"
    assert data["customer_profile"]["city"] == "Pune"
    assert data["customer_profile"]["state"] == "Maharashtra"

    # Duplicate mobile rejected
    dup_res = client.post("/api/v1/admin/users/customers", headers=headers, json=cust_payload)
    assert dup_res.status_code == 409

    # Search customer by customer ID
    cid = data["id"]
    search_res = client.get(f"/api/v1/admin/users?role=customer&search={cid}", headers=headers)
    assert search_res.status_code == 200
    assert len(search_res.json()["items"]) == 1
    assert search_res.json()["items"][0]["id"] == cid


# =============================================================================
# 3. Partner Creation with Zone Assignment & Zone Change
# =============================================================================

def test_admin_partner_zone_assignment(enhancement_db_engine, client):
    _seed_admin(enhancement_db_engine)
    headers = {"Authorization": f"Bearer {_admin_token()}"}

    # Create Zone
    z_res = client.post(
        "/api/v1/admin/zones",
        headers=headers,
        json={"name": "South Zone"},
    )
    zone_id = z_res.json()["id"]

    # Create Partner with Zone
    partner_payload = {
        "name": "Bob Partner",
        "mobile": "9876500001",
        "password": "partner_pass_123",
        "business_name": "Bob Auto Parts",
        "business_address": "123 South Road",
        "partner_code": "BOB01",
        "zone_id": zone_id,
    }
    p_res = client.post("/api/v1/admin/users/partners", headers=headers, json=partner_payload)
    assert p_res.status_code == 201
    p_data = p_res.json()
    assert p_data["zone_id"] == zone_id
    assert p_data["zone_name"] == "South Zone"

    partner_uid = p_data["id"]

    # Filter partners by zone_id in User Management
    filter_res = client.get(f"/api/v1/admin/users?role=partner&zone_id={zone_id}", headers=headers)
    assert filter_res.status_code == 200
    assert len(filter_res.json()["items"]) == 1
    assert filter_res.json()["items"][0]["zone_name"] == "South Zone"

    # Change partner zone via update endpoint
    z2_res = client.post(
        "/api/v1/admin/zones",
        headers=headers,
        json={"name": "East Zone"},
    )
    zone2_id = z2_res.json()["id"]

    update_res = client.put(
        f"/api/v1/admin/users/{partner_uid}",
        headers=headers,
        json={"zone_id": zone2_id},
    )
    assert update_res.status_code == 200
    assert update_res.json()["zone_id"] == zone2_id
    assert update_res.json()["zone_name"] == "East Zone"


# =============================================================================
# 4. Partner-Side Zone Visibility (Privacy Rule)
# =============================================================================

def test_partner_app_does_not_expose_zone(enhancement_db_engine, client):
    _seed_admin(enhancement_db_engine)
    admin_headers = {"Authorization": f"Bearer {_admin_token()}"}

    z_res = client.post(
        "/api/v1/admin/zones",
        headers=admin_headers,
        json={"name": "West Zone"},
    )
    zone_id = z_res.json()["id"]

    p_res = client.post(
        "/api/v1/admin/users/partners",
        headers=admin_headers,
        json={
            "name": "Secret Partner",
            "mobile": "9876500002",
            "password": "partner_secret_pw",
            "business_name": "West Motors",
            "business_address": "456 West Lane",
            "zone_id": zone_id,
        },
    )
    partner_uid = p_res.json()["id"]

    # Login as Partner
    login_res = client.post(
        "/api/v1/auth/partner/login",
        json={"mobile": "9876500002", "password": "partner_secret_pw"},
    )
    assert login_res.status_code == 200
    login_data = login_res.json()

    # Verify no zone info in login response
    assert "zone" not in login_data["user"]
    assert "zone_id" not in login_data["user"]
    if login_data["user"].get("partner_profile"):
        assert "zone" not in login_data["user"]["partner_profile"]
        assert "zone_id" not in login_data["user"]["partner_profile"]

    # Verify no zone info in /partner/me
    token = login_data["access_token"]
    partner_headers = {"Authorization": f"Bearer {token}"}
    me_res = client.get("/api/v1/auth/partner/me", headers=partner_headers)
    assert me_res.status_code == 200
    me_data = me_res.json()
    assert "zone" not in me_data
    assert "zone_id" not in me_data
    if me_data.get("partner_profile"):
        assert "zone" not in me_data["partner_profile"]
        assert "zone_id" not in me_data["partner_profile"]


# =============================================================================
# 5. User Editing & Deletion Safety
# =============================================================================

def test_user_edit_and_delete_safety(enhancement_db_engine, client):
    _seed_admin(enhancement_db_engine)
    headers = {"Authorization": f"Bearer {_admin_token()}"}

    # Create Staff
    s_res = client.post(
        "/api/v1/admin/users/staff",
        headers=headers,
        json={
            "name": "Sam Staff",
            "mobile": "9876500003",
            "password": "staff_pass_123",
            "staff_id": "EMP101",
        },
    )
    staff_uid = s_res.json()["id"]

    # Edit Staff
    edit_res = client.put(
        f"/api/v1/admin/users/{staff_uid}",
        headers=headers,
        json={"name": "Samuel Staff", "staff_id": "EMP101-UPDATED"},
    )
    assert edit_res.status_code == 200
    assert edit_res.json()["name"] == "Samuel Staff"
    assert edit_res.json()["staff_id"] == "EMP101-UPDATED"

    # Clean delete of Staff with no transactions
    del_res = client.delete(f"/api/v1/admin/users/{staff_uid}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["action"] == "deleted"

    # Verify user is gone
    check_res = client.get(f"/api/v1/admin/users/{staff_uid}", headers=headers)
    assert check_res.status_code == 404

    # Now create partner with an order and test soft-delete
    p_res = client.post(
        "/api/v1/admin/users/partners",
        headers=headers,
        json={
            "name": "Order Partner",
            "mobile": "9876500004",
            "password": "order_partner_pw",
            "business_name": "Order Motors",
            "business_address": "789 Order St",
        },
    )
    p_uid = p_res.json()["id"]

    # Create an order for this partner directly in DB
    with Session(enhancement_db_engine) as session:
        cat = ProductCategory(name="Lubricants")
        session.add(cat)
        session.flush()
        prod = Product(
            category_id=cat.id,
            product_code="ENG-OIL-1",
            name="Engine Oil 1L",
            vehicle_type="2-Wheeler",
            price=Decimal("450.00"),
            is_active=True,
        )
        session.add(prod)
        session.flush()
        order = Order(
            order_number="ORD-TEST-001",
            partner_id=p_uid,
            status="pending_approval",
        )
        session.add(order)
        session.flush()
        item = OrderItem(order_id=order.id, product_id=prod.id, quantity=2, unit_price=Decimal("450.00"))
        session.add(item)
        session.commit()

    # Attempt to delete partner: must NOT permanently delete historical record
    del_p_res = client.delete(f"/api/v1/admin/users/{p_uid}", headers=headers)
    assert del_p_res.status_code == 200
    assert del_p_res.json()["action"] == "deactivated"

    # Verify partner still exists in database as inactive
    detail_res = client.get(f"/api/v1/admin/users/{p_uid}", headers=headers)
    assert detail_res.status_code == 200
    assert detail_res.json()["is_active"] is False


# =============================================================================
# 6. Product Deletion Safety
# =============================================================================

def test_product_deletion_safe(enhancement_db_engine, client):
    _seed_admin(enhancement_db_engine)
    headers = {"Authorization": f"Bearer {_admin_token()}"}

    with Session(enhancement_db_engine) as session:
        cat = ProductCategory(name="Brakes")
        session.add(cat)
        session.flush()
        clean_prod = Product(
            category_id=cat.id,
            product_code="BRK-PAD-1",
            name="Clean Brake Pad",
            vehicle_type="2-Wheeler",
            price=Decimal("250.00"),
            is_active=True,
        )
        session.add(clean_prod)
        session.commit()
        clean_id = clean_prod.id

    # Clean product deletion -> deleted
    del_res = client.delete(f"/api/v1/admin/catalogue/products/{clean_id}", headers=headers)
    assert del_res.status_code == 200
    assert del_res.json()["action"] == "deleted"

    # Verify product is removed
    get_res = client.get(f"/api/v1/admin/catalogue/products/{clean_id}", headers=headers)
    assert get_res.status_code == 404


# =============================================================================
# 7. Detailed Reports (Zone-wise, Area-wise, Staff-wise, Partner-wise)
# =============================================================================

def test_detailed_reports(enhancement_db_engine, client):
    admin = _seed_admin(enhancement_db_engine)
    headers = {"Authorization": f"Bearer {_admin_token()}"}

    with Session(enhancement_db_engine) as session:
        # Create Zone
        zone = Zone(name="Central Zone", is_active=True)
        session.add(zone)
        session.flush()

        # Create Partner in Zone
        p_user = User(
            name="Central Partner",
            mobile="9111111111",
            password_hash=hash_password("pw"),
            role="partner",
            is_active=True,
        )
        session.add(p_user)
        session.flush()
        p_profile = PartnerProfile(
            user_id=p_user.id,
            business_name="Central Spares",
            business_address="MG Road, Central Market",
            zone_id=zone.id,
        )
        session.add(p_profile)

        # Create Staff
        s_user = User(
            name="Ravi Staff",
            mobile="9222222222",
            password_hash=hash_password("pw"),
            role="staff",
            is_active=True,
        )
        session.add(s_user)
        session.flush()
        s_profile = StaffProfile(user_id=s_user.id, staff_id="STF001")
        session.add(s_profile)
        session.flush()

        # Assign Staff to Partner
        assignment = StaffPartnerAssignment(
            staff_id=s_user.id,
            partner_id=p_user.id,
            is_active=True,
        )
        session.add(assignment)

        # Create Category & Product
        cat = ProductCategory(name="Tyres")
        session.add(cat)
        session.flush()
        prod = Product(
            category_id=cat.id,
            product_code="TYRE-01",
            name="Rear Tyre 100/90",
            vehicle_type="2-Wheeler",
            price=Decimal("1200.00"),
            is_active=True,
        )
        session.add(prod)
        session.flush()

        # Create Order
        order = Order(
            order_number="ORD-REPORT-001",
            partner_id=p_user.id,
            status="delivered",
            created_at=datetime.now(timezone.utc),
        )
        session.add(order)
        session.flush()
        item = OrderItem(order_id=order.id, product_id=prod.id, quantity=3, unit_price=Decimal("1200.00"))
        session.add(item)

        # Create Payment Record
        payment = StaffPaymentRecord(
            staff_id=s_user.id,
            partner_id=p_user.id,
            amount=Decimal("3600.00"),
            payment_method="cash",
            status="recorded",
            recorded_by=s_user.id,
            recorded_at=datetime.now(timezone.utc),
        )
        session.add(payment)
        session.commit()

        zid = zone.id
        pid = p_user.id
        sid = s_user.id

    # 1. Test Zone-wise report
    zr = client.get("/api/v1/admin/reports/zone-wise", headers=headers)
    assert zr.status_code == 200
    z_data = zr.json()
    assert z_data["total_zones"] >= 1
    target_zone = next((z for z in z_data["items"] if z["zone_id"] == zid), None)
    assert target_zone is not None
    assert target_zone["partner_count"] == 1
    assert target_zone["order_count"] == 1
    assert Decimal(str(target_zone["total_order_value"])) == Decimal("3600.00")
    assert Decimal(str(target_zone["total_payments_collected"])) == Decimal("3600.00")

    # 2. Test Area-wise report
    ar = client.get("/api/v1/admin/reports/area-wise", headers=headers)
    assert ar.status_code == 200
    a_data = ar.json()
    assert a_data["total_areas"] >= 1
    target_area = next((a for a in a_data["items"] if "MG Road" in a["area_name"]), None)
    assert target_area is not None
    assert target_area["order_count"] == 1
    assert Decimal(str(target_area["total_order_value"])) == Decimal("3600.00")

    # 3. Test Staff-wise report
    sr = client.get(f"/api/v1/admin/reports/staff-wise?staff_id={sid}", headers=headers)
    assert sr.status_code == 200
    s_data = sr.json()
    assert s_data["total_staff"] == 1
    stf = s_data["items"][0]
    assert stf["name"] == "Ravi Staff"
    assert stf["assigned_partner_count"] == 1
    assert stf["order_count"] == 1
    assert Decimal(str(stf["total_payments_collected"])) == Decimal("3600.00")

    # 4. Test Partner-wise report
    pr = client.get(f"/api/v1/admin/reports/partner-wise?partner_id={pid}", headers=headers)
    assert pr.status_code == 200
    p_data = pr.json()
    assert p_data["total_partners"] == 1
    ptn = p_data["items"][0]
    assert ptn["partner_name"] == "Central Partner"
    assert ptn["zone_name"] == "Central Zone"
    assert ptn["order_count"] == 1
    assert Decimal(str(ptn["total_order_value"])) == Decimal("3600.00")
    assert Decimal(str(ptn["total_payments_made"])) == Decimal("3600.00")
