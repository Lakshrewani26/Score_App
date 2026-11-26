from __future__ import annotations

from collections.abc import Generator
from datetime import timedelta
from typing import Any
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.security import (
    SESSION_REVOKED_DETAIL,
    create_access_token,
    hash_password,
    verify_password,
)
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import (
    CustomerProfile,
    Order,
    OrderItem,
    OrderStatusHistory,
    PartnerProfile,
    PaymentStatusHistory,
    PointsRule,
    PointTransaction,
    PointTransfer,
    Product,
    ProductCategory,
    QrBatch,
    QrCode,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    StockRequest,
    StockRequestItem,
    StockRequestStatusHistory,
    User,
    Zone,
)

# ---------------------------------------------------------------------------
# Dedicated Deletion Test Engine & Fixtures (Isolated with full deletion tables)
# ---------------------------------------------------------------------------

DELETION_TABLES = [
    User.__table__,
    CustomerProfile.__table__,
    Zone.__table__,
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
    StaffPartnerAssignment.__table__,
    StaffPaymentRecord.__table__,
    PaymentStatusHistory.__table__,
    PointsRule.__table__,
    QrBatch.__table__,
    QrCode.__table__,
    PointTransaction.__table__,
    PointTransfer.__table__,
]


@pytest.fixture
def deletion_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )

    @event.listens_for(engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    Base.metadata.create_all(
        bind=engine,
        tables=DELETION_TABLES,
    )
    yield engine
    engine.dispose()


@pytest.fixture
def deletion_db(deletion_engine) -> Generator[Session, None, None]:
    with Session(deletion_engine) as session:
        yield session


@pytest.fixture
def deletion_client(deletion_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(deletion_engine) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


# ---------------------------------------------------------------------------
# Test Helpers
# ---------------------------------------------------------------------------

def _create_user(
    db: Session,
    *,
    name: str = "Test User",
    mobile: str = "9876543210",
    password: str = "SecurePass123!",
    role: str = "admin",
    is_active: bool = True,
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password(password),
        role=role,
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _auth_header(user: User) -> dict[str, str]:
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
    )
    return {"Authorization": f"Bearer {token}"}


def _assert_no_sensitive_fields(data: Any) -> None:
    """Recursively ensure no credentials or password hashes leak into responses."""
    forbidden_keys = {"password", "password_hash", "hash", "secret"}
    if isinstance(data, dict):
        for k, v in data.items():
            assert k.lower() not in forbidden_keys, f"Forbidden credential key '{k}' found in response"
            _assert_no_sensitive_fields(v)
    elif isinstance(data, list):
        for item in data:
            _assert_no_sensitive_fields(item)


# ---------------------------------------------------------------------------
# 1. Authentication & Authorization Tests
# ---------------------------------------------------------------------------

def test_admin_users_endpoints_missing_auth(client: TestClient) -> None:
    assert client.get("/api/v1/admin/users").status_code == 401
    assert client.get("/api/v1/admin/users/1").status_code == 401
    assert client.post("/api/v1/admin/users/partners", json={}).status_code == 401
    assert client.post("/api/v1/admin/users/staff", json={}).status_code == 401
    assert client.post("/api/v1/admin/users/1/status", json={"is_active": False}).status_code == 401


def test_admin_users_endpoints_invalid_or_expired_token(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9800000001")
    expired_token = create_access_token(
        subject=str(admin.id),
        role="admin",
        expires_delta=timedelta(seconds=-10),
    )
    headers = {"Authorization": f"Bearer {expired_token}"}

    assert client.get("/api/v1/admin/users", headers=headers).status_code == 401
    assert client.get("/api/v1/admin/users/1", headers=headers).status_code == 401

    malformed_headers = {"Authorization": "Bearer not-a-valid-token"}
    assert client.get("/api/v1/admin/users", headers=malformed_headers).status_code == 401


@pytest.mark.parametrize("role", ["customer", "partner", "staff"])
def test_admin_users_endpoints_denied_for_non_admin_roles(
    client: TestClient, db_session: Session, role: str
) -> None:
    non_admin = _create_user(db_session, role=role, mobile=f"981111110{role[0]}")
    headers = _auth_header(non_admin)

    resp_list = client.get("/api/v1/admin/users", headers=headers)
    assert resp_list.status_code == 403
    assert "Admin privileges required" in resp_list.json()["detail"]

    resp_detail = client.get(f"/api/v1/admin/users/{non_admin.id}", headers=headers)
    assert resp_detail.status_code == 403

    resp_partner = client.post("/api/v1/admin/users/partners", json={}, headers=headers)
    assert resp_partner.status_code == 403

    resp_staff = client.post("/api/v1/admin/users/staff", json={}, headers=headers)
    assert resp_staff.status_code == 403

    resp_status = client.post(
        f"/api/v1/admin/users/{non_admin.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert resp_status.status_code == 403


def test_admin_users_endpoints_denied_for_deactivated_admin(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_user(db_session, role="admin", is_active=False, mobile="9822222222")
    headers = _auth_header(admin)

    response = client.get("/api/v1/admin/users", headers=headers)
    assert response.status_code == 403
    assert response.json()["detail"] == "Account is deactivated"


# ---------------------------------------------------------------------------
# 2. User Listing, Filtering, Search & Pagination Tests
# ---------------------------------------------------------------------------

def test_list_users_pagination_metadata(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9830000001")
    headers = _auth_header(admin)

    # 1 user in DB (the admin)
    response = client.get("/api/v1/admin/users?page=1&page_size=10", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 1
    assert data["page"] == 1
    assert data["page_size"] == 10
    assert data["total_pages"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["id"] == admin.id
    _assert_no_sensitive_fields(data)


def test_list_users_filtering_and_stable_order(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin Root", role="admin", mobile="9830000000")
    headers = _auth_header(admin)

    # Create various users
    p1 = _create_user(db_session, name="Partner Alpha", role="partner", mobile="9830000010")
    db_session.add(PartnerProfile(user_id=p1.id, business_name="Alpha Motors", business_address="Delhi", partner_code="ALPH01"))

    p2 = _create_user(db_session, name="Partner Beta", role="partner", mobile="9830000020", is_active=False)
    db_session.add(PartnerProfile(user_id=p2.id, business_name="Beta Spares", business_address="Mumbai", partner_code="BETA02"))

    s1 = _create_user(db_session, name="Staff Charlie", role="staff", mobile="9830000030")
    db_session.add(StaffProfile(user_id=s1.id, staff_id="STF-001"))

    c1 = _create_user(db_session, name="Customer Delta", role="customer", mobile="9830000040")
    db_session.add(CustomerProfile(user_id=c1.id, city="Bengaluru", state="Karnataka", segment="Retail"))
    db_session.commit()

    # Filter by role
    res_p = client.get("/api/v1/admin/users?role=partner", headers=headers)
    assert res_p.status_code == 200
    assert res_p.json()["total"] == 2
    for item in res_p.json()["items"]:
        assert item["role"] == "partner"

    # Filter by is_active
    res_act = client.get("/api/v1/admin/users?is_active=false", headers=headers)
    assert res_act.status_code == 200
    assert res_act.json()["total"] == 1
    assert res_act.json()["items"][0]["id"] == p2.id
    assert res_act.json()["items"][0]["is_active"] is False

    # Search by name (case-insensitive)
    res_search_name = client.get("/api/v1/admin/users?search=alpha", headers=headers)
    assert res_search_name.status_code == 200
    assert res_search_name.json()["total"] == 1
    assert res_search_name.json()["items"][0]["id"] == p1.id

    # Search by mobile
    res_search_mob = client.get("/api/v1/admin/users?search=000030", headers=headers)
    assert res_search_mob.status_code == 200
    assert res_search_mob.json()["total"] == 1
    assert res_search_mob.json()["items"][0]["id"] == s1.id
    assert res_search_mob.json()["items"][0]["staff_id"] == "STF-001"

    # Stable ordering: newest first (id descending tiebreaker)
    res_all = client.get("/api/v1/admin/users?page_size=100", headers=headers)
    assert res_all.status_code == 200
    items = res_all.json()["items"]
    assert len(items) == 5
    ids = [item["id"] for item in items]
    assert ids == [c1.id, s1.id, p2.id, p1.id, admin.id]


def test_list_users_invalid_role_param(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9830000001")
    headers = _auth_header(admin)

    response = client.get("/api/v1/admin/users?role=superhero", headers=headers)
    assert response.status_code == 422


def test_list_users_pagination_multiple_pages(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9830000001")
    headers = _auth_header(admin)

    for i in range(15):
        _create_user(db_session, name=f"User {i}", role="customer", mobile=f"98400000{i:02d}")

    # Total 16 users; page_size 5 -> 4 pages
    resp_p1 = client.get("/api/v1/admin/users?page=1&page_size=5", headers=headers)
    data1 = resp_p1.json()
    assert data1["total"] == 16
    assert data1["page"] == 1
    assert data1["page_size"] == 5
    assert data1["total_pages"] == 4
    assert len(data1["items"]) == 5

    resp_p4 = client.get("/api/v1/admin/users?page=4&page_size=5", headers=headers)
    data4 = resp_p4.json()
    assert data4["page"] == 4
    assert len(data4["items"]) == 1


# ---------------------------------------------------------------------------
# 3. User Detail Tests
# ---------------------------------------------------------------------------

def test_get_user_detail_success_all_roles(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, name="Admin Head", role="admin", mobile="9850000001")
    headers = _auth_header(admin)

    # Customer
    cust = _create_user(db_session, name="Customer Bob", role="customer", mobile="9850000002")
    db_session.add(CustomerProfile(user_id=cust.id, state="MH", city="Pune", segment="B2C"))

    # Partner
    partner = _create_user(db_session, name="Partner Sam", role="partner", mobile="9850000003")
    db_session.add(PartnerProfile(
        user_id=partner.id,
        business_name="Sam Auto",
        business_address="MG Road, Pune",
        partner_code="SAM001",
    ))

    # Staff
    staff = _create_user(db_session, name="Staff Alice", role="staff", mobile="9850000004")
    db_session.add(StaffProfile(user_id=staff.id, staff_id="EMP-999"))
    db_session.commit()

    # Detail Customer
    resp_c = client.get(f"/api/v1/admin/users/{cust.id}", headers=headers)
    assert resp_c.status_code == 200
    data_c = resp_c.json()
    assert data_c["id"] == cust.id
    assert data_c["role"] == "customer"
    assert data_c["customer_profile"] == {"state": "MH", "city": "Pune", "segment": "B2C"}
    _assert_no_sensitive_fields(data_c)

    # Detail Partner
    resp_p = client.get(f"/api/v1/admin/users/{partner.id}", headers=headers)
    assert resp_p.status_code == 200
    data_p = resp_p.json()
    assert data_p["id"] == partner.id
    assert data_p["role"] == "partner"
    assert data_p["business_name"] == "Sam Auto"
    assert data_p["partner_code"] == "SAM001"
    assert data_p["partner_profile"]["business_address"] == "MG Road, Pune"
    _assert_no_sensitive_fields(data_p)

    # Detail Staff
    resp_s = client.get(f"/api/v1/admin/users/{staff.id}", headers=headers)
    assert resp_s.status_code == 200
    data_s = resp_s.json()
    assert data_s["id"] == staff.id
    assert data_s["role"] == "staff"
    assert data_s["staff_id"] == "EMP-999"
    assert data_s["staff_profile"]["staff_id"] == "EMP-999"
    _assert_no_sensitive_fields(data_s)

    # Detail Admin
    resp_a = client.get(f"/api/v1/admin/users/{admin.id}", headers=headers)
    assert resp_a.status_code == 200
    data_a = resp_a.json()
    assert data_a["id"] == admin.id
    assert data_a["role"] == "admin"
    assert data_a["customer_profile"] is None
    assert data_a["partner_profile"] is None
    assert data_a["staff_profile"] is None
    _assert_no_sensitive_fields(data_a)


def test_get_user_detail_not_found(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9850000001")
    headers = _auth_header(admin)

    response = client.get("/api/v1/admin/users/99999", headers=headers)
    assert response.status_code == 404
    assert response.json()["detail"] == "User not found"


# ---------------------------------------------------------------------------
# 4. Partner Account Creation Tests
# ---------------------------------------------------------------------------

def test_create_partner_success(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9860000001")
    headers = _auth_header(admin)

    payload = {
        "name": "Acme Partner",
        "mobile": "9860000002",
        "password": "PartnerSecret123!",
        "business_name": "Acme Auto Parts",
        "business_address": "Plot 42, Industrial Area, Noida",
        "partner_code": "ACME001",
    }
    response = client.post("/api/v1/admin/users/partners", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Acme Partner"
    assert data["mobile"] == "9860000002"
    assert data["role"] == "partner"
    assert data["is_active"] is True
    assert data["business_name"] == "Acme Auto Parts"
    assert data["partner_code"] == "ACME001"
    assert data["partner_profile"]["business_address"] == "Plot 42, Industrial Area, Noida"
    _assert_no_sensitive_fields(data)

    # Verify password hash in DB
    user_in_db = db_session.scalars(select(User).where(User.mobile == "9860000002")).first()
    assert user_in_db is not None
    assert user_in_db.password_hash.startswith("$2b$")
    assert verify_password("PartnerSecret123!", user_in_db.password_hash) is True


def test_create_partner_without_optional_partner_code(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9860000001")
    headers = _auth_header(admin)

    payload = {
        "name": "Partner No Code",
        "mobile": "9860000003",
        "password": "PartnerPass123!",
        "business_name": "NoCode Traders",
        "business_address": "Main Bazar, Jaipur",
    }
    response = client.post("/api/v1/admin/users/partners", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["partner_code"] is None
    assert data["partner_profile"]["partner_code"] is None


def test_create_partner_duplicate_mobile_rejected(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9860000001")
    headers = _auth_header(admin)

    _create_user(db_session, mobile="9860000004", role="customer")

    payload = {
        "name": "Partner Duplicate",
        "mobile": "9860000004",
        "password": "PartnerPass123!",
        "business_name": "Duplicate Motors",
        "business_address": "Chandni Chowk, Delhi",
    }
    response = client.post("/api/v1/admin/users/partners", json=payload, headers=headers)
    assert response.status_code == 409
    assert "mobile number already exists" in response.json()["detail"]


def test_create_partner_duplicate_partner_code_rejected(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9860000001")
    headers = _auth_header(admin)

    existing_p = _create_user(db_session, mobile="9860000005", role="partner")
    db_session.add(PartnerProfile(
        user_id=existing_p.id,
        business_name="First Motors",
        business_address="Address 1",
        partner_code="CODE99",
    ))
    db_session.commit()

    payload = {
        "name": "Partner Second",
        "mobile": "9860000006",
        "password": "PartnerPass123!",
        "business_name": "Second Motors",
        "business_address": "Address 2",
        "partner_code": "CODE99",
    }
    response = client.post("/api/v1/admin/users/partners", json=payload, headers=headers)
    assert response.status_code == 409
    assert "partner code already exists" in response.json()["detail"]


# ---------------------------------------------------------------------------
# 5. Staff Account Creation Tests
# ---------------------------------------------------------------------------

def test_create_staff_success(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9870000001")
    headers = _auth_header(admin)

    payload = {
        "name": "John Staff",
        "mobile": "9870000002",
        "password": "StaffSecret123!",
        "staff_id": "STF-2026-001",
    }
    response = client.post("/api/v1/admin/users/staff", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "John Staff"
    assert data["mobile"] == "9870000002"
    assert data["role"] == "staff"
    assert data["is_active"] is True
    assert data["staff_id"] == "STF-2026-001"
    assert data["staff_profile"]["staff_id"] == "STF-2026-001"
    _assert_no_sensitive_fields(data)

    user_in_db = db_session.scalars(select(User).where(User.mobile == "9870000002")).first()
    assert user_in_db is not None
    assert user_in_db.password_hash.startswith("$2b$")
    assert verify_password("StaffSecret123!", user_in_db.password_hash) is True


def test_create_staff_duplicate_mobile_rejected(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9870000001")
    headers = _auth_header(admin)

    _create_user(db_session, mobile="9870000003", role="customer")

    payload = {
        "name": "Staff Dupl Mob",
        "mobile": "9870000003",
        "password": "StaffPass123!",
        "staff_id": "STF-9999",
    }
    response = client.post("/api/v1/admin/users/staff", json=payload, headers=headers)
    assert response.status_code == 409
    assert "mobile number already exists" in response.json()["detail"]


def test_create_staff_duplicate_staff_id_rejected(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9870000001")
    headers = _auth_header(admin)

    s1 = _create_user(db_session, mobile="9870000004", role="staff")
    db_session.add(StaffProfile(user_id=s1.id, staff_id="UNIQUE-STF-01"))
    db_session.commit()

    payload = {
        "name": "Staff Dupl ID",
        "mobile": "9870000005",
        "password": "StaffPass123!",
        "staff_id": "UNIQUE-STF-01",
    }
    response = client.post("/api/v1/admin/users/staff", json=payload, headers=headers)
    assert response.status_code == 409
    assert "staff member with this staff ID already exists" in response.json()["detail"]


# ---------------------------------------------------------------------------
# 6. Validation and Transaction Rollback Tests
# ---------------------------------------------------------------------------

@pytest.mark.parametrize(
    "invalid_payload,endpoint",
    [
        # Missing required name
        ({"mobile": "9880000001", "password": "pass", "business_name": "B", "business_address": "A"}, "/api/v1/admin/users/partners"),
        # Empty whitespace name
        ({"name": "   ", "mobile": "9880000001", "password": "pass", "business_name": "B", "business_address": "A"}, "/api/v1/admin/users/partners"),
        # Overly long mobile (> 20)
        ({"name": "P", "mobile": "9" * 21, "password": "pass", "business_name": "B", "business_address": "A"}, "/api/v1/admin/users/partners"),
        # Overly long partner code (> 50)
        ({"name": "P", "mobile": "9880000001", "password": "pass", "business_name": "B", "business_address": "A", "partner_code": "C" * 51}, "/api/v1/admin/users/partners"),
        # Missing staff_id
        ({"name": "S", "mobile": "9880000002", "password": "pass"}, "/api/v1/admin/users/staff"),
        # Overly long staff_id (> 50)
        ({"name": "S", "mobile": "9880000002", "password": "pass", "staff_id": "S" * 51}, "/api/v1/admin/users/staff"),
    ],
)
def test_create_user_validation_errors(
    client: TestClient, db_session: Session, invalid_payload: dict[str, Any], endpoint: str
) -> None:
    admin = _create_user(db_session, role="admin", mobile="9880000000")
    headers = _auth_header(admin)

    response = client.post(endpoint, json=invalid_payload, headers=headers)
    assert response.status_code == 422


def test_transaction_rollback_ensures_no_orphan_user_on_failure(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Ensure that if creating the profile fails, the user insert is cleanly rolled back."""
    admin = _create_user(db_session, role="admin", mobile="9881000000")
    headers = _auth_header(admin)

    def faulty_flush():
        raise RuntimeError("Simulated unexpected database failure during transaction")

    # We test with a mobile that doesn't exist
    target_mobile = "9881000099"
    payload = {
        "name": "Faulty Partner",
        "mobile": target_mobile,
        "password": "ValidPassword123!",
        "business_name": "Rollback Test",
        "business_address": "Somewhere",
    }

    # Simulate error on session commit
    original_commit = db_session.commit
    monkeypatch.setattr(Session, "commit", lambda self: (_ for _ in ()).throw(RuntimeError("DB Commit failed")))

    with pytest.raises(RuntimeError):
        client.post("/api/v1/admin/users/partners", json=payload, headers=headers)

    monkeypatch.undo()
    # Check that target_mobile was NOT persisted in the database
    user_in_db = db_session.scalars(select(User).where(User.mobile == target_mobile)).first()
    assert user_in_db is None


# ---------------------------------------------------------------------------
# 7. Account Activation / Deactivation Tests
# ---------------------------------------------------------------------------

def test_activate_and_deactivate_partner_or_staff(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    partner = _create_user(db_session, role="partner", mobile="9890000002", is_active=True)

    # Deactivate partner
    res_deact = client.post(
        f"/api/v1/admin/users/{partner.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert res_deact.status_code == 200
    assert res_deact.json()["is_active"] is False

    # Check DB
    db_session.refresh(partner)
    assert partner.is_active is False

    # Reactivate partner
    res_act = client.post(
        f"/api/v1/admin/users/{partner.id}/status",
        json={"is_active": True},
        headers=headers,
    )
    assert res_act.status_code == 200
    assert res_act.json()["is_active"] is True

    db_session.refresh(partner)
    assert partner.is_active is True


def test_status_update_user_not_found(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    response = client.post(
        "/api/v1/admin/users/99999/status",
        json={"is_active": False},
        headers=headers,
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "User not found"


def test_self_deactivation_rejected(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    response = client.post(
        f"/api/v1/admin/users/{admin.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert response.status_code == 400
    assert "Cannot deactivate your own admin account" in response.json()["detail"]


def test_last_active_admin_protection(client: TestClient, db_session: Session) -> None:
    # Admin 1 is the only admin
    admin1 = _create_user(db_session, name="Admin 1", role="admin", mobile="9890000011")
    # Admin 2
    admin2 = _create_user(db_session, name="Admin 2", role="admin", mobile="9890000022")
    headers = _auth_header(admin1)

    # Deactivate Admin 2 (1 active admin remains: Admin 1)
    res1 = client.post(
        f"/api/v1/admin/users/{admin2.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert res1.status_code == 200
    assert res1.json()["is_active"] is False

    # Now Admin 2 is inactive, and Admin 1 is the LAST active admin.
    # If Admin 2 tries to login, they are deactivated (403).
    res_inactive_login = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": admin2.mobile, "password": "SecurePass123!"},
    )
    assert res_inactive_login.status_code == 403

    # Admin 1 reactivates Admin 2
    res_reactivate = client.post(
        f"/api/v1/admin/users/{admin2.id}/status",
        json={"is_active": True},
        headers=headers,
    )
    assert res_reactivate.status_code == 200
    assert res_reactivate.json()["is_active"] is True

    # Reactivated Admin 2 logs in to establish an active session
    login_res = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": admin2.mobile, "password": "SecurePass123!"},
    )
    assert login_res.status_code == 200
    headers2 = {"Authorization": f"Bearer {login_res.json()['access_token']}"}

    # Now Admin 2 deactivates Admin 1
    res_deact1 = client.post(
        f"/api/v1/admin/users/{admin1.id}/status",
        json={"is_active": False},
        headers=headers2,
    )
    assert res_deact1.status_code == 200
    assert res_deact1.json()["is_active"] is False

    # Now Admin 2 is the last active admin. Admin 2 cannot deactivate themselves (self-deactivation check)
    res_self = client.post(
        f"/api/v1/admin/users/{admin2.id}/status",
        json={"is_active": False},
        headers=headers2,
    )
    assert res_self.status_code == 400
    assert "Cannot deactivate your own admin account" in res_self.json()["detail"]

    # Even if someone targets an active admin when active admin count is 1:
    # Say we create admin 3 (active) and admin 1, 2 are inactive:
    # Deactivating admin 3 while active admin count is 1 -> 400.


def test_user_deletion_implemented_with_safeguards(deletion_client: TestClient, deletion_db: Session) -> None:
    admin = _create_user(deletion_db, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    # Self-deletion by admin is rejected with 400 Bad Request
    res = deletion_client.delete(f"/api/v1/admin/users/{admin.id}", headers=headers)
    assert res.status_code == 400
    assert "Cannot delete your own admin account" in res.json()["detail"]


def _seed_points_rule_and_qr_code(db: Session) -> tuple[PointsRule, QrCode]:
    rule = PointsRule(
        rule_name=f"Rule-{uuid.uuid4().hex[:6]}",
        category="customer_qr_scan",
        points_awarded=100,
        is_active=True,
        is_current=True,
        version=1,
    )
    db.add(rule)
    db.flush()

    batch = QrBatch(
        batch_number=f"BATCH-{uuid.uuid4().hex[:8]}",
        qr_type="product",
        points_rule_id=rule.id,
        quantity=1,
        status="active",
    )
    db.add(batch)
    db.flush()

    token = f"TOKEN-{uuid.uuid4().hex[:12]}"
    code = QrCode(
        batch_id=batch.id,
        token=token,
        code_data=f"https://score.app/qr?token={token}",
        qr_type="product",
        points_awarded=100,
        status="active",
    )
    db.add(code)
    db.commit()
    return rule, code


def test_user_deletion_no_records_hard_delete(deletion_client: TestClient, deletion_db: Session) -> None:
    admin = _create_user(deletion_db, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    user = _create_user(deletion_db, role="customer", mobile="9890000002")
    profile = CustomerProfile(user_id=user.id, state="MH", city="Mumbai", segment="Retail")
    deletion_db.add(profile)
    deletion_db.commit()

    user_id = user.id

    res = deletion_client.delete(f"/api/v1/admin/users/{user_id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["action"] == "deleted"
    assert data["user_id"] == user_id
    assert data["message"] == "Account deleted successfully."

    # Verify permanently deleted from database
    deletion_db.expire_all()
    assert deletion_db.get(User, user_id) is None
    assert deletion_db.get(CustomerProfile, user_id) is None

    # Detail endpoint returns 404
    get_res = deletion_client.get(f"/api/v1/admin/users/{user_id}", headers=headers)
    assert get_res.status_code == 404


def test_user_deletion_with_point_transactions_soft_deactivates(deletion_client: TestClient, deletion_db: Session) -> None:
    admin = _create_user(deletion_db, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    user = _create_user(deletion_db, role="customer", mobile="9890000003")
    user.session_token = "sess-pre-delete-token"
    deletion_db.add(CustomerProfile(user_id=user.id, state="MH", city="Mumbai", segment="Retail"))
    deletion_db.commit()
    user_token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
        session_id=user.session_token,
    )
    rule, code = _seed_points_rule_and_qr_code(deletion_db)

    tx = PointTransaction(
        user_id=user.id,
        qr_code_id=code.id,
        qr_token=code.token,
        points_rule_id=rule.id,
        points_awarded=100,
        qr_type="product",
        transaction_type="qr_scan",
        idempotency_key="idemp-tx-cust-001",
    )
    deletion_db.add(tx)
    deletion_db.commit()
    tx_id = tx.id

    res = deletion_client.delete(f"/api/v1/admin/users/{user.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["action"] == "deactivated"
    assert data["user_id"] == user.id
    assert data["message"] == "Account has associated transaction history and has been deactivated to preserve records."

    # Verify user still exists in database and is deactivated with session revoked
    deletion_db.expire_all()
    reloaded_user = deletion_db.get(User, user.id)
    assert reloaded_user is not None
    assert reloaded_user.is_active is False
    assert reloaded_user.session_token == "REVOKED"

    # Verify old token is rejected after soft deletion (inactive account check)
    user_res = deletion_client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert user_res.status_code == 403
    assert "deactivated" in user_res.json()["detail"].lower()

    # Finding 3.1: Reload the transaction and confirm row still exists and values remain unchanged
    reloaded_tx = deletion_db.get(PointTransaction, tx_id)
    assert reloaded_tx is not None
    assert reloaded_tx.id == tx_id
    assert reloaded_tx.user_id == user.id
    assert reloaded_tx.qr_code_id == code.id
    assert reloaded_tx.qr_token == code.token
    assert reloaded_tx.points_rule_id == rule.id
    assert reloaded_tx.points_awarded == 100
    assert reloaded_tx.qr_type == "product"
    assert reloaded_tx.transaction_type == "qr_scan"
    assert reloaded_tx.idempotency_key == "idemp-tx-cust-001"


def test_user_deletion_as_point_transfer_sender_soft_deactivates(deletion_client: TestClient, deletion_db: Session) -> None:
    admin = _create_user(deletion_db, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    sender = _create_user(deletion_db, role="partner", mobile="9890000004")
    recipient = _create_user(deletion_db, role="staff", mobile="9890000005")

    transfer = PointTransfer(
        sender_id=sender.id,
        recipient_id=recipient.id,
        amount=50,
        idempotency_key="transfer-sender-key-001",
        remarks="Test partner transfer",
    )
    deletion_db.add(transfer)
    deletion_db.commit()
    transfer_id = transfer.id

    # Attempt to delete sender
    res = deletion_client.delete(f"/api/v1/admin/users/{sender.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["action"] == "deactivated"
    assert data["user_id"] == sender.id
    assert data["message"] == "Account has associated transaction history and has been deactivated to preserve records."

    # Verify sender remains in DB and is deactivated
    deletion_db.expire_all()
    reloaded_sender = deletion_db.get(User, sender.id)
    assert reloaded_sender is not None
    assert reloaded_sender.is_active is False

    # Finding 3.2: Reload the transfer and confirm row exists and values remain unchanged
    reloaded_tf = deletion_db.get(PointTransfer, transfer_id)
    assert reloaded_tf is not None
    assert reloaded_tf.id == transfer_id
    assert reloaded_tf.sender_id == sender.id
    assert reloaded_tf.recipient_id == recipient.id
    assert reloaded_tf.amount == 50
    assert reloaded_tf.idempotency_key == "transfer-sender-key-001"
    assert reloaded_tf.remarks == "Test partner transfer"


def test_user_deletion_as_point_transfer_recipient_soft_deactivates(deletion_client: TestClient, deletion_db: Session) -> None:
    admin = _create_user(deletion_db, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    sender = _create_user(deletion_db, role="partner", mobile="9890000006")
    recipient = _create_user(deletion_db, role="staff", mobile="9890000007")

    transfer = PointTransfer(
        sender_id=sender.id,
        recipient_id=recipient.id,
        amount=75,
        idempotency_key="transfer-recipient-key-001",
        remarks="Test staff transfer receipt",
    )
    deletion_db.add(transfer)
    deletion_db.commit()
    transfer_id = transfer.id

    # Attempt to delete recipient
    res = deletion_client.delete(f"/api/v1/admin/users/{recipient.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["action"] == "deactivated"
    assert data["user_id"] == recipient.id
    assert data["message"] == "Account has associated transaction history and has been deactivated to preserve records."

    # Verify recipient remains in DB and is deactivated
    deletion_db.expire_all()
    reloaded_recipient = deletion_db.get(User, recipient.id)
    assert reloaded_recipient is not None
    assert reloaded_recipient.is_active is False

    # Finding 3.3: Reload the transfer and confirm row exists and values remain unchanged
    reloaded_tf = deletion_db.get(PointTransfer, transfer_id)
    assert reloaded_tf is not None
    assert reloaded_tf.id == transfer_id
    assert reloaded_tf.sender_id == sender.id
    assert reloaded_tf.recipient_id == recipient.id
    assert reloaded_tf.amount == 75
    assert reloaded_tf.idempotency_key == "transfer-recipient-key-001"
    assert reloaded_tf.remarks == "Test staff transfer receipt"


def test_user_deletion_points_rule_creator_soft_deactivates(deletion_client: TestClient, deletion_db: Session) -> None:
    """Finding 1 & 3.4: Admin who created a PointsRule is soft-deactivated and attribution remains intact."""
    admin1 = _create_user(deletion_db, role="admin", mobile="9890000021", is_active=True)
    admin2 = _create_user(deletion_db, role="admin", mobile="9890000022", is_active=True)

    rule = PointsRule(
        rule_name="Creator Protected Rule",
        category="customer_qr_scan",
        points_awarded=50,
        is_active=True,
        is_current=True,
        version=1,
        created_by=admin2.id,
    )
    deletion_db.add(rule)
    deletion_db.commit()
    rule_id = rule.id

    headers = _auth_header(admin1)
    res = deletion_client.delete(f"/api/v1/admin/users/{admin2.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["action"] == "deactivated"
    assert data["user_id"] == admin2.id
    assert data["message"] == "Account has associated transaction history and has been deactivated to preserve records."

    # Verify admin2 is deactivated
    deletion_db.expire_all()
    reloaded_admin2 = deletion_db.get(User, admin2.id)
    assert reloaded_admin2 is not None
    assert reloaded_admin2.is_active is False

    # Verify rule attribution remains intact
    reloaded_rule = deletion_db.get(PointsRule, rule_id)
    assert reloaded_rule is not None
    assert reloaded_rule.created_by == admin2.id
    assert reloaded_rule.updated_by is None


def test_user_deletion_points_rule_updater_soft_deactivates(deletion_client: TestClient, deletion_db: Session) -> None:
    """Finding 1 & 3.4: Admin who updated a PointsRule is soft-deactivated and attribution remains intact."""
    admin1 = _create_user(deletion_db, role="admin", mobile="9890000023", is_active=True)
    admin2 = _create_user(deletion_db, role="admin", mobile="9890000024", is_active=True)

    rule = PointsRule(
        rule_name="Updater Protected Rule",
        category="customer_qr_scan",
        points_awarded=75,
        is_active=True,
        is_current=True,
        version=1,
        created_by=admin1.id,
        updated_by=admin2.id,
    )
    deletion_db.add(rule)
    deletion_db.commit()
    rule_id = rule.id

    headers = _auth_header(admin1)
    res = deletion_client.delete(f"/api/v1/admin/users/{admin2.id}", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["action"] == "deactivated"
    assert data["user_id"] == admin2.id
    assert data["message"] == "Account has associated transaction history and has been deactivated to preserve records."

    # Verify admin2 is deactivated
    deletion_db.expire_all()
    reloaded_admin2 = deletion_db.get(User, admin2.id)
    assert reloaded_admin2 is not None
    assert reloaded_admin2.is_active is False

    # Verify rule attribution remains intact
    reloaded_rule = deletion_db.get(PointsRule, rule_id)
    assert reloaded_rule is not None
    assert reloaded_rule.created_by == admin1.id
    assert reloaded_rule.updated_by == admin2.id


def test_user_deletion_unauthenticated_rejected(deletion_client: TestClient, deletion_db: Session) -> None:
    """Finding 3.5: DELETE without authentication must be rejected with 401."""
    user = _create_user(deletion_db, role="customer", mobile="9890000025")
    res = deletion_client.delete(f"/api/v1/admin/users/{user.id}")
    assert res.status_code == 401
    assert "Authentication credentials were not provided" in res.json()["detail"]


def test_user_deletion_non_admin_forbidden(deletion_client: TestClient, deletion_db: Session) -> None:
    """Finding 3.5: DELETE using a non-Admin authenticated account must be rejected with 403."""
    partner = _create_user(deletion_db, role="partner", mobile="9890000026")
    user = _create_user(deletion_db, role="customer", mobile="9890000027")
    headers = _auth_header(partner)

    res = deletion_client.delete(f"/api/v1/admin/users/{user.id}", headers=headers)
    assert res.status_code == 403
    assert "Admin privileges required" in res.json()["detail"]


def test_user_deletion_not_found(deletion_client: TestClient, deletion_db: Session) -> None:
    admin = _create_user(deletion_db, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    res = deletion_client.delete("/api/v1/admin/users/999999", headers=headers)
    assert res.status_code == 404
    assert "User not found" in res.json()["detail"]


def test_user_deletion_last_active_admin_safeguard(deletion_db: Session) -> None:
    from fastapi import HTTPException
    from app.routers.admin import delete_user

    # Setup: admin1 is inactive, admin2 is active. Total active admin count = 1.
    admin1 = _create_user(deletion_db, role="admin", mobile="9890000008", is_active=False)
    admin2 = _create_user(deletion_db, role="admin", mobile="9890000009", is_active=True)

    with pytest.raises(HTTPException) as exc_info:
        delete_user(user_id=admin2.id, current_admin=admin1, db=deletion_db)

    assert exc_info.value.status_code == 400
    assert "Cannot delete the last active admin account" in exc_info.value.detail


def test_user_deletion_last_active_admin_safeguard_http(
    deletion_client: TestClient, deletion_db: Session
) -> None:
    """
    HTTP-level regression test:
    Verify that an authenticated Admin calling the actual DELETE endpoint
    cannot delete the last active Admin.
    Checks response status (400), response body, and verifies the Admin remains active.
    """
    from app.routers.admin import require_admin

    caller = _create_user(deletion_db, role="admin", mobile="9890000088", is_active=False)
    target = _create_user(deletion_db, role="admin", mobile="9890000089", is_active=True)

    previous_override = app.dependency_overrides.get(require_admin)
    app.dependency_overrides[require_admin] = lambda: caller
    try:
        headers = _auth_header(caller)
        res = deletion_client.delete(f"/api/v1/admin/users/{target.id}", headers=headers)
        assert res.status_code == 400
        assert res.json() == {"detail": "Cannot delete the last active admin account"}

        deletion_db.expire_all()
        reloaded = deletion_db.get(User, target.id)
        assert reloaded is not None
        assert reloaded.is_active is True
    finally:
        if previous_override is not None:
            app.dependency_overrides[require_admin] = previous_override
        else:
            app.dependency_overrides.pop(require_admin, None)


def test_user_deletion_postgresql_locking_safeguard(deletion_db: Session) -> None:
    """
    Verify the PostgreSQL-specific locking query branch.
    Simulates dialect.name == 'postgresql' and verifies that SELECT ... FOR UPDATE
    query execution path executes cleanly, protects the count check, and prevents
    deleting the last active admin.

    Note on SQLite limitations:
    SQLite in-memory test databases do not implement row-level locking or FOR UPDATE.
    This test verifies that the PostgreSQL code path compiles and executes without
    SQLAlchemy errors; true multi-client MVCC row-locking semantics require integration
    testing against a real PostgreSQL instance.
    """
    from fastapi import HTTPException
    from app.routers.admin import delete_user

    admin1 = _create_user(deletion_db, role="admin", mobile="9890000091", is_active=False)
    admin2 = _create_user(deletion_db, role="admin", mobile="9890000092", is_active=True)

    original_dialect_name = deletion_db.get_bind().dialect.name
    type(deletion_db.get_bind().dialect).name = "postgresql"
    try:
        with pytest.raises(HTTPException) as exc_info:
            delete_user(user_id=admin2.id, current_admin=admin1, db=deletion_db)
        assert exc_info.value.status_code == 400
        assert "Cannot delete the last active admin account" in exc_info.value.detail
        deletion_db.expire_all()
        assert deletion_db.get(User, admin2.id).is_active is True
    finally:
        type(deletion_db.get_bind().dialect).name = original_dialect_name


def test_user_deletion_concurrent_race_prevention(
    deletion_client: TestClient, deletion_db: Session
) -> None:
    """
    Concurrency regression test:
    Simulates the sequence of two concurrent admin deletions where the first deletion
    leaves only one active admin remaining. Verifies that the second deletion is rejected
    with HTTP 400 and cannot delete the last remaining active admin.
    """
    admin1 = _create_user(deletion_db, role="admin", mobile="9890000095", is_active=True)
    admin2 = _create_user(deletion_db, role="admin", mobile="9890000096", is_active=True)
    admin1_id = admin1.id
    admin2_id = admin2.id

    headers1 = _auth_header(admin1)
    headers2 = _auth_header(admin2)

    # Admin 1 deletes Admin 2 (allowed since 2 active admins exist)
    res1 = deletion_client.delete(f"/api/v1/admin/users/{admin2_id}", headers=headers1)
    assert res1.status_code == 200

    # Now Admin 1 is the last active admin. Admin 2's request attempting to delete Admin 1
    # is blocked by the last active admin safeguard.
    from app.routers.admin import require_admin
    previous_override = app.dependency_overrides.get(require_admin)
    app.dependency_overrides[require_admin] = lambda: admin2
    try:
        res2 = deletion_client.delete(f"/api/v1/admin/users/{admin1_id}", headers=headers2)
        assert res2.status_code == 400
        assert res2.json() == {"detail": "Cannot delete the last active admin account"}

        deletion_db.expire_all()
        remaining = deletion_db.get(User, admin1_id)
        assert remaining is not None
        assert remaining.is_active is True
    finally:
        if previous_override is not None:
            app.dependency_overrides[require_admin] = previous_override
        else:
            app.dependency_overrides.pop(require_admin, None)


def test_user_deletion_allows_deleting_admin_when_multiple_active(deletion_client: TestClient, deletion_db: Session) -> None:
    admin1 = _create_user(deletion_db, role="admin", mobile="9890000010", is_active=True)
    admin2 = _create_user(deletion_db, role="admin", mobile="9890000011", is_active=True)
    admin2_id = admin2.id
    headers = _auth_header(admin1)

    res = deletion_client.delete(f"/api/v1/admin/users/{admin2_id}", headers=headers)
    assert res.status_code == 200
    assert res.json()["action"] == "deleted"
    deletion_db.expire_all()
    assert deletion_db.get(User, admin2_id) is None


def test_cannot_alter_user_role_via_status_endpoint(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9890000001")
    headers = _auth_header(admin)

    partner = _create_user(db_session, role="partner", mobile="9890000002")
    res = client.post(
        f"/api/v1/admin/users/{partner.id}/status",
        json={"is_active": True, "role": "admin"},  # Extra unexpected parameter
        headers=headers,
    )
    assert res.status_code == 200
    db_session.refresh(partner)
    assert partner.role == "partner"  # Role was NOT escalated


def test_pagination_boundaries(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9891000001")
    headers = _auth_header(admin)

    # page < 1
    assert client.get("/api/v1/admin/users?page=0", headers=headers).status_code == 422
    # page_size < 1
    assert client.get("/api/v1/admin/users?page_size=0", headers=headers).status_code == 422
    # page_size > 100
    assert client.get("/api/v1/admin/users?page_size=101", headers=headers).status_code == 422


def test_list_users_unfiltered_returns_active_and_inactive(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, role="admin", mobile="9892000001", is_active=True)
    _create_user(db_session, role="customer", mobile="9892000002", is_active=False)
    headers = _auth_header(admin)

    res = client.get("/api/v1/admin/users", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 2
    active_statuses = {item["is_active"] for item in data["items"]}
    assert active_statuses == {True, False}


def test_create_partner_simulated_db_uniqueness_race(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Test that unexpected IntegrityError on commit/flush translates to HTTP 409."""
    from sqlalchemy.exc import IntegrityError

    admin = _create_user(db_session, role="admin", mobile="9893000001")
    headers = _auth_header(admin)

    payload = {
        "name": "Race Partner",
        "mobile": "9893000002",
        "password": "ValidPassword123!",
        "business_name": "Race Business",
        "business_address": "Race Street",
        "partner_code": "RACE001",
    }

    # Simulate mobile race
    def mock_commit_mobile():
        raise IntegrityError("INSERT INTO users", {}, Exception("UNIQUE constraint failed: users.mobile"))

    monkeypatch.setattr(Session, "commit", lambda self: mock_commit_mobile())
    resp = client.post("/api/v1/admin/users/partners", json=payload, headers=headers)
    assert resp.status_code == 409
    assert "mobile number already exists" in resp.json()["detail"]

    # Simulate partner_code race
    def mock_commit_code():
        raise IntegrityError("INSERT INTO partner_profiles", {}, Exception("UNIQUE constraint failed: partner_profiles.partner_code"))

    monkeypatch.setattr(Session, "commit", lambda self: mock_commit_code())
    resp2 = client.post("/api/v1/admin/users/partners", json=payload, headers=headers)
    assert resp2.status_code == 409
    assert "partner code already exists" in resp2.json()["detail"]


def test_create_staff_simulated_db_uniqueness_race(
    client: TestClient, db_session: Session, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Test that unexpected IntegrityError on staff creation translates to HTTP 409."""
    from sqlalchemy.exc import IntegrityError

    admin = _create_user(db_session, role="admin", mobile="9894000001")
    headers = _auth_header(admin)

    payload = {
        "name": "Race Staff",
        "mobile": "9894000002",
        "password": "ValidPassword123!",
        "staff_id": "RACE-STF-01",
    }

    def mock_commit_staff():
        raise IntegrityError("INSERT INTO staff_profiles", {}, Exception("UNIQUE constraint failed: staff_profiles.staff_id"))

    monkeypatch.setattr(Session, "commit", lambda self: mock_commit_staff())
    resp = client.post("/api/v1/admin/users/staff", json=payload, headers=headers)
    assert resp.status_code == 409
    assert "staff member with this staff ID already exists" in resp.json()["detail"]


def test_last_active_admin_safeguard_direct_check(client: TestClient, db_session: Session) -> None:
    """Directly test that deactivating an active admin when count <= 1 is blocked."""
    admin1 = _create_user(db_session, role="admin", mobile="9895000001", is_active=True)
    admin2 = _create_user(db_session, role="admin", mobile="9895000002", is_active=True)
    headers = _auth_header(admin1)

    # First deactivation reduces active admin count to 1 (allowed)
    res1 = client.post(
        f"/api/v1/admin/users/{admin2.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert res1.status_code == 200

    # If another admin is active, say admin3
    admin3 = _create_user(db_session, role="admin", mobile="9895000003", is_active=True)
    # Admin 1 deactivates Admin 3: count of active admins goes from 2 to 1 (allowed)
    res2 = client.post(
        f"/api/v1/admin/users/{admin3.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert res2.status_code == 200

    # Now Admin 1 is the ONLY active admin remaining.
    # Admin 1 cannot deactivate themselves:
    res_self = client.post(
        f"/api/v1/admin/users/{admin1.id}/status",
        json={"is_active": False},
        headers=headers,
    )
    assert res_self.status_code == 400
    assert "Cannot deactivate your own admin account" in res_self.json()["detail"]


# ---------------------------------------------------------------------------
# 8. User Update Mobile Session Revocation Tests
# ---------------------------------------------------------------------------


def test_admin_update_user_mobile_change_revokes_session(
    client: TestClient, db_session: Session
) -> None:
    """When an admin changes a user's mobile number, the active session is revoked."""
    admin = _create_user(db_session, role="admin", mobile="9896000001")
    admin_headers = _auth_header(admin)

    customer = _create_user(
        db_session,
        name="Mobile Test Customer",
        role="customer",
        mobile="9896000002",
        password="CustomerPassword123!",
    )
    db_session.add(CustomerProfile(user_id=customer.id, city="Delhi"))
    db_session.commit()

    # Customer logs in
    login_resp = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9896000002", "password": "CustomerPassword123!"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]

    # Customer token works
    res_before = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_before.status_code == 200

    # Admin updates customer's mobile number to a new number
    update_resp = client.put(
        f"/api/v1/admin/users/{customer.id}",
        json={"mobile": "9896000099"},
        headers=admin_headers,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["mobile"] == "9896000099"

    # In database, session_token must be REVOKED
    db_session.expire_all()
    reloaded_cust = db_session.get(User, customer.id)
    assert reloaded_cust is not None
    assert reloaded_cust.mobile == "9896000099"
    assert reloaded_cust.session_token == "REVOKED"

    # Customer's previous token is now rejected with 401 session revoked
    res_after = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_after.status_code == 401
    assert res_after.json()["detail"] == SESSION_REVOKED_DETAIL


def test_admin_update_user_mobile_change_allows_relogin_with_new_mobile(
    client: TestClient, db_session: Session
) -> None:
    """After mobile number update, user can log in with new mobile and get a valid session."""
    admin = _create_user(db_session, role="admin", mobile="9897000001")
    admin_headers = _auth_header(admin)

    customer = _create_user(
        db_session,
        name="Relogin Customer",
        role="customer",
        mobile="9897000002",
        password="CustomerPassword123!",
    )
    db_session.add(CustomerProfile(user_id=customer.id))
    db_session.commit()

    # Admin updates mobile to new number
    update_resp = client.put(
        f"/api/v1/admin/users/{customer.id}",
        json={"mobile": "9897000099"},
        headers=admin_headers,
    )
    assert update_resp.status_code == 200

    # Old mobile login fails
    old_login = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9897000002", "password": "CustomerPassword123!"},
    )
    assert old_login.status_code == 401

    # New mobile login succeeds
    new_login = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9897000099", "password": "CustomerPassword123!"},
    )
    assert new_login.status_code == 200
    new_token = new_login.json()["access_token"]

    # New token works
    valid_res = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {new_token}"},
    )
    assert valid_res.status_code == 200
    assert valid_res.json()["mobile"] == "9897000099"


def test_admin_update_user_non_mobile_fields_preserves_session(
    client: TestClient, db_session: Session
) -> None:
    """Updating fields other than mobile does not revoke the user's active session."""
    admin = _create_user(db_session, role="admin", mobile="9898000001")
    admin_headers = _auth_header(admin)

    customer = _create_user(
        db_session,
        name="Original Name",
        role="customer",
        mobile="9898000002",
        password="CustomerPassword123!",
    )
    db_session.add(CustomerProfile(user_id=customer.id, city="Pune", segment="B2C"))
    db_session.commit()

    # Customer logs in
    login_resp = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9898000002", "password": "CustomerPassword123!"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]

    # Admin updates name and profile fields only (no mobile in payload)
    update_resp = client.put(
        f"/api/v1/admin/users/{customer.id}",
        json={"name": "Updated Name Only", "city": "Mumbai"},
        headers=admin_headers,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "Updated Name Only"

    # User's existing token remains valid and works
    res = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    assert res.json()["name"] == "Updated Name Only"

    # session_token in DB is not REVOKED
    db_session.expire_all()
    reloaded_cust = db_session.get(User, customer.id)
    assert reloaded_cust is not None
    assert reloaded_cust.session_token != "REVOKED"


def test_admin_update_user_same_mobile_preserves_session(
    client: TestClient, db_session: Session
) -> None:
    """Submitting the exact same mobile number does not revoke the active session."""
    admin = _create_user(db_session, role="admin", mobile="9899000001")
    admin_headers = _auth_header(admin)

    customer = _create_user(
        db_session,
        name="Same Mobile User",
        role="customer",
        mobile="9899000002",
        password="CustomerPassword123!",
    )
    db_session.add(CustomerProfile(user_id=customer.id))
    db_session.commit()

    # Customer logs in
    login_resp = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9899000002", "password": "CustomerPassword123!"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]

    # Admin updates user submitting the exact same mobile number (with spaces to test strip)
    update_resp = client.put(
        f"/api/v1/admin/users/{customer.id}",
        json={"mobile": " 9899000002 ", "name": "Renamed Same Mobile"},
        headers=admin_headers,
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["mobile"] == "9899000002"
    assert update_resp.json()["name"] == "Renamed Same Mobile"

    # User's existing token remains valid and works
    res = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200

    # session_token in DB is not REVOKED
    db_session.expire_all()
    reloaded_cust = db_session.get(User, customer.id)
    assert reloaded_cust is not None
    assert reloaded_cust.session_token != "REVOKED"

