from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Generator
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.config import settings
from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import (
    CustomerProfile,
    PartnerProfile,
    PointTransaction,
    PointTransfer,
    PointsRule,
    Product,
    ProductCategory,
    QrBatch,
    QrCode,
    StaffPartnerAssignment,
    StaffProfile,
    User,
)
from app.services.points_service import get_user_points_balance

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
    with engine.begin() as conn:
        conn.exec_driver_sql("PRAGMA foreign_keys = ON")
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture
def db(test_engine) -> Generator[Session, None, None]:
    with Session(test_engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def client(test_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine, expire_on_commit=False) as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def make_auth_headers(user: User) -> dict[str, str]:
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
    )
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def seed_data(db: Session):
    now = datetime.now(timezone.utc)

    # 1. Users
    partner_user = User(
        name="Apex Motors Partner",
        mobile="9811111111",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    staff_user = User(
        name="Rajesh Kumar Staff",
        mobile="9822222221",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    staff_user_inactive = User(
        name="Inactive Staff",
        mobile="9822222229",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=False,
    )
    customer_user = User(
        name="Ramesh Customer",
        mobile="9833333331",
        password_hash=hash_password("Cust@123"),
        role="customer",
        is_active=True,
    )
    admin_user = User(
        name="Super Admin",
        mobile="9844444441",
        password_hash=hash_password("Admin@123"),
        role="admin",
        is_active=True,
    )
    db.add_all([partner_user, staff_user, staff_user_inactive, customer_user, admin_user])
    db.flush()

    # 2. Profiles
    p_profile = PartnerProfile(
        user_id=partner_user.id,
        business_name="Apex Motors",
        business_address="100 Auto Nagar",
        partner_code="PAR-APX",
    )
    s_profile = StaffProfile(
        user_id=staff_user.id,
        staff_id="STF-001",
    )
    s_inactive_profile = StaffProfile(
        user_id=staff_user_inactive.id,
        staff_id="STF-INACT",
    )
    c_profile = CustomerProfile(
        user_id=customer_user.id,
        state="Maharashtra",
        city="Pune",
        segment="Retail",
    )
    assignment = StaffPartnerAssignment(
        staff_id=staff_user.id,
        partner_id=partner_user.id,
        is_active=True,
    )
    db.add_all([p_profile, s_profile, s_inactive_profile, c_profile, assignment])
    db.flush()

    # 3. Product & Categories for product/invoice QR batches
    category = ProductCategory(name="Brakes", is_active=True)
    db.add(category)
    db.flush()

    product = Product(
        category_id=category.id,
        product_code="BRK-001",
        name="Front Brake Shoe",
        vehicle_type="2-Wheeler",
        price=350.0,
        is_active=True,
    )
    db.add(product)
    db.flush()

    # 4. Batches
    batch_staff = QrBatch(
        batch_number="BATCH-STF-RES-001",
        qr_type="staff",
        quantity=10,
        created_by=admin_user.id,
    )
    batch_product = QrBatch(
        batch_number="BATCH-PRD-RES-001",
        qr_type="product",
        quantity=5,
        product_id=product.id,
        created_by=admin_user.id,
    )
    batch_invoice = QrBatch(
        batch_number="BATCH-INV-RES-001",
        qr_type="invoice",
        quantity=5,
        created_by=admin_user.id,
    )
    db.add_all([batch_staff, batch_product, batch_invoice])
    db.flush()

    # 5. QR Codes
    # 5a. Valid Active Staff QR
    qr_valid_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_VALID_TOKEN_111",
        code_data="score://qr/v1?token=STAFF_VALID_TOKEN_111&type=staff",
        target_user_id=staff_user.id,
        points_awarded=100,
        status="active",
        expires_at=now + timedelta(days=30),
    )
    # 5b. Expired Staff QR
    qr_expired_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_EXPIRED_TOKEN_222",
        code_data="score://qr/v1?token=STAFF_EXPIRED_TOKEN_222&type=staff",
        target_user_id=staff_user.id,
        points_awarded=100,
        status="active",
        expires_at=now - timedelta(hours=2),
    )
    # 5c. Voided Staff QR
    qr_voided_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_VOIDED_TOKEN_333",
        code_data="score://qr/v1?token=STAFF_VOIDED_TOKEN_333&type=staff",
        target_user_id=staff_user.id,
        points_awarded=100,
        status="voided",
    )
    # 5d. Redeemed Staff QR
    qr_redeemed_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_REDEEMED_TOKEN_444",
        code_data="score://qr/v1?token=STAFF_REDEEMED_TOKEN_444&type=staff",
        target_user_id=staff_user.id,
        points_awarded=100,
        status="redeemed",
    )
    # 5e. Unassigned Staff QR (target_user_id is None)
    qr_unassigned_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_UNASSIGNED_TOKEN_555",
        code_data="score://qr/v1?token=STAFF_UNASSIGNED_TOKEN_555&type=staff",
        target_user_id=None,
        status="active",
    )
    # 5f. Staff QR assigned to non-staff user (customer)
    qr_non_staff_assigned = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_ASSIGNED_TO_CUST_666",
        code_data="score://qr/v1?token=STAFF_ASSIGNED_TO_CUST_666&type=staff",
        target_user_id=customer_user.id,
        status="active",
    )
    # 5g. Staff QR assigned to inactive staff user
    qr_inactive_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_INACTIVE_USER_777",
        code_data="score://qr/v1?token=STAFF_INACTIVE_USER_777&type=staff",
        target_user_id=staff_user_inactive.id,
        status="active",
    )
    # 5h. Product QR
    qr_product = QrCode(
        batch_id=batch_product.id,
        qr_type="product",
        token="PRODUCT_TOKEN_888",
        code_data="score://qr/v1?token=PRODUCT_TOKEN_888&type=product",
        product_id=product.id,
        status="active",
    )
    # 5i. Invoice QR
    qr_invoice = QrCode(
        batch_id=batch_invoice.id,
        qr_type="invoice",
        token="INVOICE_TOKEN_999",
        code_data="score://qr/v1?token=INVOICE_TOKEN_999&type=invoice",
        status="active",
    )

    db.add_all([
        qr_valid_staff,
        qr_expired_staff,
        qr_voided_staff,
        qr_redeemed_staff,
        qr_unassigned_staff,
        qr_non_staff_assigned,
        qr_inactive_staff,
        qr_product,
        qr_invoice,
    ])
    db.commit()

    return {
        "partner_user": partner_user,
        "staff_user": staff_user,
        "staff_user_inactive": staff_user_inactive,
        "customer_user": customer_user,
        "admin_user": admin_user,
        "qr_valid_staff": qr_valid_staff,
        "qr_expired_staff": qr_expired_staff,
        "qr_voided_staff": qr_voided_staff,
        "qr_redeemed_staff": qr_redeemed_staff,
        "qr_unassigned_staff": qr_unassigned_staff,
        "qr_non_staff_assigned": qr_non_staff_assigned,
        "qr_inactive_staff": qr_inactive_staff,
        "qr_product": qr_product,
        "qr_invoice": qr_invoice,
    }


# ============================================================================
# 1. Success Resolution Tests
# ============================================================================

def test_partner_can_resolve_valid_active_staff_qr_with_raw_token(client: TestClient, seed_data):
    """
    Partner can resolve an active Staff QR code using the raw token.
    Returns staff user ID, name, staff badge ID, qr_code_id, and qr_type.
    """
    partner = seed_data["partner_user"]
    staff = seed_data["staff_user"]
    qr = seed_data["qr_valid_staff"]

    headers = make_auth_headers(partner)
    payload = {"token": qr.token}

    response = client.post("/api/v1/staff/qr/resolve", json=payload, headers=headers)
    assert response.status_code == 200, response.text
    data = response.json()

    assert data["staff_user_id"] == staff.id
    assert data["staff_name"] == staff.name
    assert data["staff_id"] == "STF-001"
    assert data["qr_code_id"] == qr.id
    assert data["qr_type"] == "staff"


def test_partner_can_resolve_valid_active_staff_qr_with_url_code_data(client: TestClient, seed_data):
    """
    Partner can resolve a Staff QR code by passing the full scanned code_data URL.
    """
    partner = seed_data["partner_user"]
    staff = seed_data["staff_user"]
    qr = seed_data["qr_valid_staff"]

    headers = make_auth_headers(partner)
    payload = {"code_data": qr.code_data}

    response = client.post("/api/v1/staff/qr/resolve", json=payload, headers=headers)
    assert response.status_code == 200, response.text
    data = response.json()

    assert data["staff_user_id"] == staff.id
    assert data["staff_name"] == staff.name
    assert data["staff_id"] == "STF-001"
    assert data["qr_code_id"] == qr.id
    assert data["qr_type"] == "staff"


def test_resolve_does_not_expose_sensitive_fields(client: TestClient, seed_data):
    """
    Confirm response strictly exposes only the necessary minimal fields
    and does NOT expose password_hash, mobile, internal audit fields, or points balance.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]

    headers = make_auth_headers(partner)
    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 200
    data = response.json()

    # Exact key set assertion
    expected_keys = {"staff_user_id", "staff_name", "staff_id", "qr_code_id", "qr_type"}
    assert set(data.keys()) == expected_keys

    # Confirm sensitive information is completely absent
    assert "password_hash" not in data
    assert "mobile" not in data
    assert "batch_id" not in data
    assert "created_by" not in data
    assert "points_awarded" not in data
    assert "points_balance" not in data
    assert "balance" not in data


# ============================================================================
# 2. Authorization Tests (Only Partner Permitted)
# ============================================================================

def test_unauthenticated_request_is_rejected_with_401(client: TestClient, seed_data):
    """Unauthenticated call to /qr/resolve must return 401 Unauthorized."""
    qr = seed_data["qr_valid_staff"]
    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token})
    assert response.status_code == 401


def test_customer_cannot_resolve_staff_qr_rejected_with_403(client: TestClient, seed_data):
    """Customer role calling /qr/resolve must return 403 Forbidden."""
    customer = seed_data["customer_user"]
    qr = seed_data["qr_valid_staff"]

    headers = make_auth_headers(customer)
    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 403
    assert "Partner privileges required" in response.text


def test_staff_cannot_resolve_staff_qr_rejected_with_403(client: TestClient, seed_data):
    """Staff role calling /qr/resolve must return 403 Forbidden."""
    staff = seed_data["staff_user"]
    qr = seed_data["qr_valid_staff"]

    headers = make_auth_headers(staff)
    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 403
    assert "Partner privileges required" in response.text


def test_admin_cannot_resolve_staff_qr_rejected_with_403(client: TestClient, seed_data):
    """Admin role calling /qr/resolve must return 403 Forbidden (requires Partner role)."""
    admin = seed_data["admin_user"]
    qr = seed_data["qr_valid_staff"]

    headers = make_auth_headers(admin)
    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 403
    assert "Partner privileges required" in response.text


# ============================================================================
# 3. QR Token & Status Validation Tests
# ============================================================================

def test_nonexistent_token_rejected_with_404(client: TestClient, seed_data):
    """Nonexistent QR token returns 404 Not Found."""
    partner = seed_data["partner_user"]
    headers = make_auth_headers(partner)

    response = client.post(
        "/api/v1/staff/qr/resolve",
        json={"token": "DOES_NOT_EXIST_TOKEN_99999"},
        headers=headers,
    )
    assert response.status_code == 404
    assert "Staff QR code token not found" in response.text


def test_oversized_token_rejected_with_404(client: TestClient, seed_data):
    """Token longer than 64 characters is cleanly rejected with 404 Not Found."""
    partner = seed_data["partner_user"]
    headers = make_auth_headers(partner)

    oversized = "A" * 70
    response = client.post(
        "/api/v1/staff/qr/resolve",
        json={"token": oversized},
        headers=headers,
    )
    assert response.status_code == 404
    assert "Staff QR code token not found" in response.text


def test_empty_payload_rejected_with_422(client: TestClient, seed_data):
    """Empty payload or missing token/code_data is rejected."""
    partner = seed_data["partner_user"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={}, headers=headers)
    assert response.status_code == 422


def test_product_qr_token_rejected_with_400(client: TestClient, seed_data):
    """Product QR tokens cannot be resolved as Staff recipients (400 Bad Request)."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_product"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "Inappropriate QR code type" in response.text
    assert "product" in response.text


def test_invoice_qr_token_rejected_with_400(client: TestClient, seed_data):
    """Invoice QR tokens cannot be resolved as Staff recipients (400 Bad Request)."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_invoice"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "Inappropriate QR code type" in response.text
    assert "invoice" in response.text


def test_voided_staff_qr_rejected_with_400(client: TestClient, seed_data):
    """Voided Staff QR code is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_voided_staff"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "not active" in response.text
    assert "voided" in response.text


def test_redeemed_staff_qr_rejected_with_400(client: TestClient, seed_data):
    """Redeemed Staff QR code is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_redeemed_staff"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "not active" in response.text
    assert "redeemed" in response.text


def test_expired_staff_qr_rejected_with_400(client: TestClient, seed_data):
    """Expired Staff QR code is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_expired_staff"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "This Staff QR code has expired" in response.text


def test_unassigned_staff_qr_rejected_with_400(client: TestClient, seed_data):
    """Staff QR code with target_user_id is None is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_unassigned_staff"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "not assigned to any staff member" in response.text


def test_staff_qr_assigned_to_non_staff_user_rejected_with_400(client: TestClient, seed_data):
    """Staff QR assigned to a non-Staff user (e.g. customer) is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_non_staff_assigned"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "does not hold the 'staff' role" in response.text


def test_staff_qr_assigned_to_inactive_staff_user_rejected_with_400(client: TestClient, seed_data):
    """Staff QR assigned to a deactivated staff user is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_inactive_staff"]
    headers = make_auth_headers(partner)

    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 400
    assert "Assigned staff user account is inactive" in response.text


# ============================================================================
# 4. Zero ID Enumeration & Read-Only Invariance Tests
# ============================================================================

def test_endpoint_does_not_permit_arbitrary_user_id_lookup(client: TestClient, seed_data):
    """
    Supplying an arbitrary user_id without a valid token must be rejected.
    Extra fields are ignored by schema and a valid token is required.
    """
    partner = seed_data["partner_user"]
    staff = seed_data["staff_user"]
    headers = make_auth_headers(partner)

    # Attempting to query by user_id directly without token
    response = client.post(
        "/api/v1/staff/qr/resolve",
        json={"user_id": staff.id},
        headers=headers,
    )
    assert response.status_code == 422


def test_resolution_is_purely_read_only_and_creates_no_transfers_or_balance_changes(
    client: TestClient, db: Session, seed_data
):
    """
    Confirm resolving a Staff QR creates zero PointTransfer rows, zero PointTransaction rows,
    and does NOT alter either Partner or Staff balances.
    """
    partner = seed_data["partner_user"]
    staff = seed_data["staff_user"]
    qr = seed_data["qr_valid_staff"]

    # Initial state
    initial_transfer_count = db.scalar(select(func.count(PointTransfer.id))) or 0
    initial_tx_count = db.scalar(select(func.count(PointTransaction.id))) or 0
    initial_partner_balance = get_user_points_balance(db, partner.id, role="partner").current_balance
    initial_staff_balance = get_user_points_balance(db, staff.id, role="staff").current_balance

    headers = make_auth_headers(partner)
    response = client.post("/api/v1/staff/qr/resolve", json={"token": qr.token}, headers=headers)
    assert response.status_code == 200

    # Post-state check
    final_transfer_count = db.scalar(select(func.count(PointTransfer.id))) or 0
    final_tx_count = db.scalar(select(func.count(PointTransaction.id))) or 0
    final_partner_balance = get_user_points_balance(db, partner.id, role="partner").current_balance
    final_staff_balance = get_user_points_balance(db, staff.id, role="staff").current_balance

    assert final_transfer_count == initial_transfer_count
    assert final_tx_count == initial_tx_count
    assert final_partner_balance == initial_partner_balance
    assert final_staff_balance == initial_staff_balance
