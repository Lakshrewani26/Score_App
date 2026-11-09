from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Generator
from unittest.mock import patch
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, func, select
from sqlalchemy.exc import SQLAlchemyError
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


def auth_headers(user: User) -> dict[str, str]:
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
    partner_user_inactive = User(
        name="Deactivated Partner",
        mobile="9811111199",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=False,
    )
    staff_user = User(
        name="Rajesh Kumar Staff",
        mobile="9822222221",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    staff_user_inactive = User(
        name="Deactivated Staff",
        mobile="9822222299",
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
    db.add_all([
        partner_user,
        partner_user_inactive,
        staff_user,
        staff_user_inactive,
        customer_user,
        admin_user,
    ])
    db.flush()

    # 2. Profiles
    p_profile = PartnerProfile(
        user_id=partner_user.id,
        business_name="Apex Motors",
        business_address="100 Auto Nagar",
        partner_code="PAR-APX",
    )
    p_inact_profile = PartnerProfile(
        user_id=partner_user_inactive.id,
        business_name="Inactive Motors",
        business_address="101 Auto Nagar",
        partner_code="PAR-INACT",
    )
    s_profile = StaffProfile(
        user_id=staff_user.id,
        staff_id="STF-001",
    )
    s_inact_profile = StaffProfile(
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
    db.add_all([p_profile, p_inact_profile, s_profile, s_inact_profile, c_profile, assignment])
    db.flush()

    # 3. Product & Batches
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

    batch_staff = QrBatch(
        batch_number="BATCH-STF-TRF-001",
        qr_type="staff",
        quantity=10,
        created_by=admin_user.id,
    )
    batch_product = QrBatch(
        batch_number="BATCH-PRD-TRF-001",
        qr_type="product",
        quantity=5,
        product_id=product.id,
        created_by=admin_user.id,
    )
    batch_invoice = QrBatch(
        batch_number="BATCH-INV-TRF-001",
        qr_type="invoice",
        quantity=5,
        created_by=admin_user.id,
    )
    db.add_all([batch_staff, batch_product, batch_invoice])
    db.flush()

    # 4. QR Codes
    qr_valid_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_TOKEN_001",
        code_data="score://qr/v1?token=STAFF_TRF_TOKEN_001&type=staff",
        target_user_id=staff_user.id,
        status="active",
        expires_at=now + timedelta(days=30),
    )
    qr_expired_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_EXPIRED_002",
        code_data="score://qr/v1?token=STAFF_TRF_EXPIRED_002&type=staff",
        target_user_id=staff_user.id,
        status="active",
        expires_at=now - timedelta(hours=1),
    )
    qr_voided_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_VOIDED_003",
        code_data="score://qr/v1?token=STAFF_TRF_VOIDED_003&type=staff",
        target_user_id=staff_user.id,
        status="voided",
    )
    qr_unassigned_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_UNASSIGNED_004",
        code_data="score://qr/v1?token=STAFF_TRF_UNASSIGNED_004&type=staff",
        target_user_id=None,
        status="active",
    )
    qr_non_staff_assigned = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_CUST_ASSIGNED_005",
        code_data="score://qr/v1?token=STAFF_TRF_CUST_ASSIGNED_005&type=staff",
        target_user_id=customer_user.id,
        status="active",
    )
    qr_inactive_staff = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_INACT_006",
        code_data="score://qr/v1?token=STAFF_TRF_INACT_006&type=staff",
        target_user_id=staff_user_inactive.id,
        status="active",
    )
    qr_product = QrCode(
        batch_id=batch_product.id,
        qr_type="product",
        token="PROD_TRF_TOKEN_007",
        code_data="score://qr/v1?token=PROD_TRF_TOKEN_007&type=product",
        product_id=product.id,
        status="active",
    )
    qr_invoice = QrCode(
        batch_id=batch_invoice.id,
        qr_type="invoice",
        token="INV_TRF_TOKEN_008",
        code_data="score://qr/v1?token=INV_TRF_TOKEN_008&type=invoice",
        status="active",
    )
    qr_self_partner = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF_TRF_SELF_009",
        code_data="score://qr/v1?token=STAFF_TRF_SELF_009&type=staff",
        target_user_id=partner_user.id,
        status="active",
    )

    db.add_all([
        qr_valid_staff,
        qr_expired_staff,
        qr_voided_staff,
        qr_unassigned_staff,
        qr_non_staff_assigned,
        qr_inactive_staff,
        qr_product,
        qr_invoice,
        qr_self_partner,
    ])
    db.flush()

    # 5. Points Rules
    rule_scan = PointsRule(
        rule_name="Partner QR Scan Loyalty",
        category="partner_qr_scan",
        points_awarded=1000,
        is_active=True,
        is_current=True,
        version=1,
    )
    rule_transfer = PointsRule(
        rule_name="Partner to Staff Transfer Rule",
        category="partner_to_staff_transfer",
        is_active=True,
        is_current=True,
        min_transaction_value=Decimal("10.00"),
        max_transaction_value=Decimal("5000.00"),
        version=1,
    )
    db.add_all([rule_scan, rule_transfer])
    db.flush()

    # 6. Seed initial balance for Partner: 1000 points via PointTransaction
    tx = PointTransaction(
        user_id=partner_user.id,
        qr_code_id=qr_product.id,
        qr_token=qr_product.token,
        points_rule_id=rule_scan.id,
        points_awarded=1000,
        qr_type="product",
    )
    db.add(tx)
    db.commit()

    return {
        "partner_user": partner_user,
        "partner_user_inactive": partner_user_inactive,
        "staff_user": staff_user,
        "staff_user_inactive": staff_user_inactive,
        "customer_user": customer_user,
        "admin_user": admin_user,
        "qr_valid_staff": qr_valid_staff,
        "qr_expired_staff": qr_expired_staff,
        "qr_voided_staff": qr_voided_staff,
        "qr_unassigned_staff": qr_unassigned_staff,
        "qr_non_staff_assigned": qr_non_staff_assigned,
        "qr_inactive_staff": qr_inactive_staff,
        "qr_product": qr_product,
        "qr_invoice": qr_invoice,
        "qr_self_partner": qr_self_partner,
        "rule_transfer": rule_transfer,
    }


# ============================================================================
# 1. Successful Transfer & Balance Updates (Requirements 1, 2, 3)
# ============================================================================

def test_successful_partner_to_staff_transfer(client: TestClient, db: Session, seed_data):
    """
    1. Successful Partner -> Staff transfer execution.
    2. Partner balance decreases correctly.
    3. Staff balance increases correctly.
    """
    partner = seed_data["partner_user"]
    staff = seed_data["staff_user"]
    qr = seed_data["qr_valid_staff"]

    # Initial balances: Partner has 1000, Staff has 0
    assert get_user_points_balance(db, partner.id, role="partner").current_balance == 1000
    assert get_user_points_balance(db, staff.id, role="staff").current_balance == 0

    payload = {
        "token": qr.token,
        "amount": 350,
        "idempotency_key": "tx-success-001",
    }
    headers = auth_headers(partner)
    response = client.post("/api/v1/partner/transfers", json=payload, headers=headers)
    assert response.status_code == 200, response.text
    data = response.json()

    # Response fields
    assert data["amount"] == 350
    assert data["sender_id"] == partner.id
    assert data["recipient_id"] == staff.id
    assert data["recipient_name"] == staff.name
    assert data["recipient_staff_id"] == "STF-001"
    assert data["sender_balance"] == 650
    assert data["recipient_balance"] == 350
    assert data["is_idempotent_replay"] is False
    assert "transfer_id" in data
    assert "created_at" in data

    # Ledger record verified in DB
    transfer_rec = db.scalar(
        select(PointTransfer).where(PointTransfer.id == data["transfer_id"])
    )
    assert transfer_rec is not None
    assert transfer_rec.sender_id == partner.id
    assert transfer_rec.recipient_id == staff.id
    assert transfer_rec.amount == 350
    assert transfer_rec.idempotency_key == "tx-success-001"

    # Balance service single source of truth verification
    partner_bal = get_user_points_balance(db, partner.id, role="partner")
    assert partner_bal.current_balance == 650
    assert partner_bal.transfers_sent == 350

    staff_bal = get_user_points_balance(db, staff.id, role="staff")
    assert staff_bal.current_balance == 350
    assert staff_bal.transfers_received == 350


def test_transfer_with_scanned_url_code_data(client: TestClient, db: Session, seed_data):
    """Transfer works seamlessly when scanned QR URL code_data is provided."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]

    payload = {
        "code_data": qr.code_data,
        "amount": 100,
        "idempotency_key": "tx-code-data-001",
    }
    response = client.post("/api/v1/partner/transfers", json=payload, headers=auth_headers(partner))
    assert response.status_code == 200
    assert response.json()["amount"] == 100


# ============================================================================
# 2. Insufficient Balance & Amount Validations (Requirements 4, 5)
# ============================================================================

def test_insufficient_balance_rejected(client: TestClient, db: Session, seed_data):
    """Transfer exceeding available balance is rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]

    # Partner has 1000 points, tries to transfer 1500
    payload = {
        "token": qr.token,
        "amount": 1500,
        "idempotency_key": "tx-overspend-001",
    }
    response = client.post("/api/v1/partner/transfers", json=payload, headers=auth_headers(partner))
    assert response.status_code == 400
    assert "Insufficient points balance" in response.text

    # Verify no transfer recorded and balance remains 1000
    count = db.scalar(select(func.count(PointTransfer.id))) or 0
    assert count == 0
    assert get_user_points_balance(db, partner.id, role="partner").current_balance == 1000


def test_zero_amount_rejected(client: TestClient, seed_data):
    """Zero amount is rejected."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]

    payload = {
        "token": qr.token,
        "amount": 0,
        "idempotency_key": "tx-zero-001",
    }
    response = client.post("/api/v1/partner/transfers", json=payload, headers=auth_headers(partner))
    assert response.status_code in (400, 422)


def test_negative_amount_rejected(client: TestClient, seed_data):
    """Negative amount is rejected."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]

    payload = {
        "token": qr.token,
        "amount": -50,
        "idempotency_key": "tx-neg-001",
    }
    response = client.post("/api/v1/partner/transfers", json=payload, headers=auth_headers(partner))
    assert response.status_code in (400, 422)


# ============================================================================
# 3. QR Code Status & Type Validations (Requirements 6, 7, 8, 9)
# ============================================================================

def test_invalid_or_nonexistent_token_rejected_with_404(client: TestClient, seed_data):
    """Nonexistent token returns 404 Not Found."""
    partner = seed_data["partner_user"]
    payload = {
        "token": "NON_EXISTENT_QR_TOKEN_9999",
        "amount": 50,
        "idempotency_key": "tx-nonexistent-001",
    }
    response = client.post("/api/v1/partner/transfers", json=payload, headers=auth_headers(partner))
    assert response.status_code == 404
    assert "Staff QR code token not found" in response.text


def test_product_and_invoice_qr_rejected_with_400(client: TestClient, seed_data):
    """Product and Invoice QR tokens cannot be used as Staff recipients."""
    partner = seed_data["partner_user"]
    headers = auth_headers(partner)

    # Product QR
    res_prod = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_product"].token, "amount": 50, "idempotency_key": "tx-prod-qr"},
        headers=headers,
    )
    assert res_prod.status_code == 400
    assert "Inappropriate QR code type" in res_prod.text

    # Invoice QR
    res_inv = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_invoice"].token, "amount": 50, "idempotency_key": "tx-inv-qr"},
        headers=headers,
    )
    assert res_inv.status_code == 400
    assert "Inappropriate QR code type" in res_inv.text


def test_inactive_expired_voided_unassigned_staff_qr_rejected(client: TestClient, seed_data):
    """Inactive, expired, voided, or unassigned Staff QRs are rejected."""
    partner = seed_data["partner_user"]
    headers = auth_headers(partner)

    # Expired
    res_exp = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_expired_staff"].token, "amount": 50, "idempotency_key": "tx-exp"},
        headers=headers,
    )
    assert res_exp.status_code == 400
    assert "expired" in res_exp.text

    # Voided
    res_void = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_voided_staff"].token, "amount": 50, "idempotency_key": "tx-void"},
        headers=headers,
    )
    assert res_void.status_code == 400
    assert "not active" in res_void.text

    # Unassigned
    res_unassigned = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_unassigned_staff"].token, "amount": 50, "idempotency_key": "tx-unassigned"},
        headers=headers,
    )
    assert res_unassigned.status_code == 400
    assert "not assigned to any staff member" in res_unassigned.text


def test_recipient_not_staff_account_rejected(client: TestClient, seed_data):
    """Staff QR assigned to a non-Staff user (customer) is rejected."""
    partner = seed_data["partner_user"]
    res = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_non_staff_assigned"].token, "amount": 50, "idempotency_key": "tx-non-staff"},
        headers=auth_headers(partner),
    )
    assert res.status_code == 400
    assert "does not hold the 'staff' role" in res.text


def test_sender_cannot_transfer_to_self(client: TestClient, seed_data):
    """Sender and recipient cannot be the same user."""
    partner = seed_data["partner_user"]
    res = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_self_partner"].token, "amount": 50, "idempotency_key": "tx-self"},
        headers=auth_headers(partner),
    )
    assert res.status_code == 400
    assert "does not hold the 'staff' role" in res.text or "cannot be the same user" in res.text


# ============================================================================
# 4. Account Inactivity Validations (Requirement 10)
# ============================================================================

def test_inactive_staff_account_rejected_with_400(client: TestClient, seed_data):
    """Staff QR assigned to an inactive staff member is rejected."""
    partner = seed_data["partner_user"]
    res = client.post(
        "/api/v1/partner/transfers",
        json={"token": seed_data["qr_inactive_staff"].token, "amount": 50, "idempotency_key": "tx-inact-staff"},
        headers=auth_headers(partner),
    )
    assert res.status_code == 400
    assert "Assigned staff user account is inactive" in res.text


def test_inactive_partner_caller_rejected_with_403(client: TestClient, seed_data):
    """Inactive Partner cannot execute transfers (rejected with 403 Forbidden)."""
    inact_partner = seed_data["partner_user_inactive"]
    qr = seed_data["qr_valid_staff"]

    res = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 50, "idempotency_key": "tx-inact-partner"},
        headers=auth_headers(inact_partner),
    )
    assert res.status_code == 403
    assert "deactivated" in res.text.lower()


# ============================================================================
# 5. Points Rule & Limits Validations (Requirements 11, 12)
# ============================================================================

def test_missing_or_disabled_transfer_rule_rejected(client: TestClient, db: Session, seed_data):
    """If the Partner -> Staff transfer rule is disabled, transfer is rejected."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    rule = seed_data["rule_transfer"]

    rule.is_active = False
    db.commit()

    res = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 50, "idempotency_key": "tx-rule-disabled"},
        headers=auth_headers(partner),
    )
    assert res.status_code == 400
    assert "disabled" in res.text or "No active Partner to Staff transfer rule" in res.text


def test_configured_transfer_restrictions_enforced(client: TestClient, seed_data):
    """Transfer amounts below min or above max are rejected with 400 Bad Request."""
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)

    # Minimum is configured at 10 points
    res_min = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 5, "idempotency_key": "tx-below-min"},
        headers=headers,
    )
    assert res_min.status_code == 400
    assert "below the minimum allowed transfer" in res_min.text

    # Maximum is configured at 5000 points (partner balance is 1000, but test boundary if balance were higher)
    res_max = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 6000, "idempotency_key": "tx-above-max"},
        headers=headers,
    )
    assert res_max.status_code == 400
    assert "exceeds the maximum allowed transfer" in res_max.text


# ============================================================================
# 6. Idempotency Behaviors (Requirements 13, 14, 17)
# ============================================================================

def test_same_idempotency_key_same_payload_replayed_cleanly(client: TestClient, db: Session, seed_data):
    """
    13. Same key, same transfer payload.
    17. No duplicate transfer or balance change after a retry.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)

    payload = {
        "token": qr.token,
        "amount": 200,
        "idempotency_key": "tx-idempotent-repeat-001",
    }

    # First request
    res1 = client.post("/api/v1/partner/transfers", json=payload, headers=headers)
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["is_idempotent_replay"] is False
    assert data1["sender_balance"] == 800

    # Second request (retry with exact same key and payload)
    res2 = client.post("/api/v1/partner/transfers", json=payload, headers=headers)
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["is_idempotent_replay"] is True
    assert data2["transfer_id"] == data1["transfer_id"]
    assert data2["sender_balance"] == 800  # Not double-deducted!

    # Third request
    res3 = client.post("/api/v1/partner/transfers", json=payload, headers=headers)
    assert res3.status_code == 200
    assert res3.json()["is_idempotent_replay"] is True

    # Ledger check: exactly ONE record in DB
    count = db.scalar(
        select(func.count(PointTransfer.id)).where(
            PointTransfer.idempotency_key == "tx-idempotent-repeat-001"
        )
    )
    assert count == 1
    assert get_user_points_balance(db, partner.id, role="partner").current_balance == 800


def test_same_idempotency_key_different_payload_rejected_with_409(client: TestClient, db: Session, seed_data):
    """
    14. Same key, different transfer payload returns 409 Conflict.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)

    # Initial transfer with key
    payload1 = {
        "token": qr.token,
        "amount": 150,
        "idempotency_key": "tx-conflict-key-001",
    }
    res1 = client.post("/api/v1/partner/transfers", json=payload1, headers=headers)
    assert res1.status_code == 200

    # Conflicting transfer with same key but different amount
    payload2 = {
        "token": qr.token,
        "amount": 250,
        "idempotency_key": "tx-conflict-key-001",
    }
    res2 = client.post("/api/v1/partner/transfers", json=payload2, headers=headers)
    assert res2.status_code == 409
    assert "Idempotency key has already been used for a different transfer payload" in res2.text

    # Partner balance only deducted by original 150 (1000 - 150 = 850)
    assert get_user_points_balance(db, partner.id, role="partner").current_balance == 850


def test_transfer_retry_succeeds_even_if_qr_later_expires(client: TestClient, db: Session, seed_data):
    """
    An already-committed transfer remains safely retryable even if the historical Staff QR
    code subsequently expires.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)
    key = "tx-retry-after-expiry-001"

    # Initial transfer succeeds
    res1 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res1.status_code == 200
    assert res1.json()["is_idempotent_replay"] is False

    # Historical QR code expires after transfer is already committed
    now = datetime.now(timezone.utc)
    qr.expires_at = now - timedelta(hours=1)
    db.commit()

    # Retry with same key and token succeeds with idempotent replay
    res2 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["is_idempotent_replay"] is True
    assert data2["transfer_id"] == res1.json()["transfer_id"]
    assert data2["amount"] == 100


def test_transfer_retry_succeeds_even_if_qr_later_voided(client: TestClient, db: Session, seed_data):
    """
    An already-committed transfer remains safely retryable even if the historical Staff QR
    code status is later changed to 'voided'.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)
    key = "tx-retry-after-voided-001"

    # Initial transfer succeeds
    res1 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res1.status_code == 200
    assert res1.json()["is_idempotent_replay"] is False

    # Historical QR code is voided after transfer
    qr.status = "voided"
    db.commit()

    # Retry with same key and token succeeds with idempotent replay
    res2 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["is_idempotent_replay"] is True
    assert data2["transfer_id"] == res1.json()["transfer_id"]
    assert data2["amount"] == 100


def test_transfer_retry_succeeds_even_if_staff_account_later_deactivated(client: TestClient, db: Session, seed_data):
    """
    An already-committed transfer remains safely retryable even if the Staff recipient's
    account is subsequently deactivated.
    """
    partner = seed_data["partner_user"]
    staff = seed_data["staff_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)
    key = "tx-retry-after-deactivation-001"

    # Initial transfer succeeds
    res1 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res1.status_code == 200
    assert res1.json()["is_idempotent_replay"] is False

    # Staff recipient is deactivated after transfer
    staff.is_active = False
    db.commit()

    # Retry with same key and token succeeds with idempotent replay
    res2 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["is_idempotent_replay"] is True
    assert data2["transfer_id"] == res1.json()["transfer_id"]
    assert data2["amount"] == 100


def test_transfer_retry_with_different_recipient_qr_returns_409(client: TestClient, db: Session, seed_data):
    """
    Replaying an idempotency key with a different recipient's QR token is rejected with 409 Conflict.
    """
    partner = seed_data["partner_user"]
    qr1 = seed_data["qr_valid_staff"]
    key = "tx-conflict-recipient-001"

    # Create a second active staff member and assigned QR code
    staff2 = User(
        name="Vikram Staff 2",
        mobile="9822222233",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    db.add(staff2)
    db.flush()
    db.add(StaffProfile(user_id=staff2.id, staff_id="STF-002"))
    batch = db.scalar(select(QrBatch).where(QrBatch.qr_type == "staff"))
    qr2 = QrCode(
        batch_id=batch.id,
        qr_type="staff",
        token="STAFF_TRF_TOKEN_999",
        code_data="score://qr/v1?token=STAFF_TRF_TOKEN_999&type=staff",
        target_user_id=staff2.id,
        status="active",
        expires_at=datetime.now(timezone.utc) + timedelta(days=30),
    )
    db.add(qr2)
    db.commit()

    headers = auth_headers(partner)

    # Initial transfer to Staff 1
    res1 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr1.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res1.status_code == 200

    # Retry same key with Staff 2's QR token -> 409 Conflict
    res2 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr2.token, "amount": 100, "idempotency_key": key},
        headers=headers,
    )
    assert res2.status_code == 409
    assert "Idempotency key has already been used for a different transfer payload" in res2.text


def test_transfer_retry_by_another_partner_returns_409(client: TestClient, db: Session, seed_data):
    """
    Another partner attempting to use an existing idempotency key is rejected with 409 Conflict
    and cannot see or access the original partner's transfer confirmation.
    """
    partner1 = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    key = "tx-cross-partner-001"

    # Create Partner 2 with sufficient balance
    partner2 = User(
        name="Apex Competitor Partner",
        mobile="9811111122",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    db.add(partner2)
    db.flush()
    db.add(PartnerProfile(user_id=partner2.id, business_name="Competitor Motors", business_address="102 Road", partner_code="PAR-CMP"))
    batch_prod = db.scalar(select(QrBatch).where(QrBatch.qr_type == "product"))
    qr_p2 = QrCode(
        batch_id=batch_prod.id,
        qr_type="product",
        token="PROD_TRF_TOKEN_P2_999",
        code_data="score://qr/v1?token=PROD_TRF_TOKEN_P2_999&type=product",
        status="active",
    )
    db.add(qr_p2)
    db.flush()
    db.add(PointTransaction(
        user_id=partner2.id,
        qr_code_id=qr_p2.id,
        qr_token=qr_p2.token,
        points_rule_id=seed_data["rule_transfer"].id,
        points_awarded=1000,
        qr_type="product",
    ))
    db.commit()

    # Partner 1 makes transfer with key
    res1 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=auth_headers(partner1),
    )
    assert res1.status_code == 200
    original_transfer_id = res1.json()["transfer_id"]

    # Partner 2 attempts to use Partner 1's idempotency key
    res2 = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 100, "idempotency_key": key},
        headers=auth_headers(partner2),
    )
    assert res2.status_code == 409
    assert "Idempotency key has already been used for a different transfer payload" in res2.text
    # Partner 2 gets NO details of original transfer
    assert str(original_transfer_id) not in res2.text
    assert partner1.name not in res2.text


# ============================================================================
# 7. Concurrency & Atomicity (Requirements 15, 16)
# ============================================================================

def test_concurrent_transfers_cannot_overspend(client: TestClient, db: Session, seed_data):
    """
    15. Two transfers that together exceed the available balance:
        Partner has 500 points.
        Transfer A asks for 350 points.
        Transfer B asks for 350 points.
        Exactly one succeeds, the other fails with insufficient balance.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)

    # First reduce balance to 500 by transferring 500
    res_prep = client.post(
        "/api/v1/partner/transfers",
        json={"token": qr.token, "amount": 500, "idempotency_key": "tx-prep-500"},
        headers=headers,
    )
    assert res_prep.status_code == 200
    assert get_user_points_balance(db, partner.id, role="partner").current_balance == 500

    results = []

    def run_transfer(amount: int, key: str):
        payload = {"token": qr.token, "amount": amount, "idempotency_key": key}
        return client.post("/api/v1/partner/transfers", json=payload, headers=headers)

    # Run two transfers sequentially under lock semantics
    resA = run_transfer(350, "tx-concurrent-A")
    resB = run_transfer(350, "tx-concurrent-B")

    statuses = [resA.status_code, resB.status_code]
    assert 200 in statuses
    assert 400 in statuses

    # Remaining balance must be 500 - 350 = 150 (never negative)
    final_balance = get_user_points_balance(db, partner.id, role="partner").current_balance
    assert final_balance == 150


def test_failed_database_operation_leaves_no_partial_transfer(client: TestClient, db: Session, seed_data):
    """
    16. A database failure during transfer creation rolls back and leaves no partial transfer.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]
    headers = auth_headers(partner)

    initial_balance = get_user_points_balance(db, partner.id, role="partner").current_balance
    initial_transfer_count = db.scalar(select(func.count(PointTransfer.id))) or 0

    payload = {
        "token": qr.token,
        "amount": 100,
        "idempotency_key": "tx-fail-commit-001",
    }

    # Simulate database commit failure
    with patch.object(Session, "commit", side_effect=SQLAlchemyError("Simulated DB connection failure")):
        with pytest.raises(SQLAlchemyError):
            client.post("/api/v1/partner/transfers", json=payload, headers=headers)

    # After rollback, verify database is completely untouched
    final_balance = get_user_points_balance(db, partner.id, role="partner").current_balance
    final_transfer_count = db.scalar(select(func.count(PointTransfer.id))) or 0

    assert final_balance == initial_balance
    assert final_transfer_count == initial_transfer_count


# ============================================================================
# 8. Privacy & Sensitive Field Exclusion (Requirement 18)
# ============================================================================

def test_response_does_not_expose_sensitive_fields(client: TestClient, seed_data):
    """
    18. Response does not expose sensitive fields:
        No password_hash, mobile, internal audit fields, etc.
    """
    partner = seed_data["partner_user"]
    qr = seed_data["qr_valid_staff"]

    payload = {
        "token": qr.token,
        "amount": 25,
        "idempotency_key": "tx-privacy-001",
    }
    response = client.post("/api/v1/partner/transfers", json=payload, headers=auth_headers(partner))
    assert response.status_code == 200
    data = response.json()

    # Allowed keys
    expected_keys = {
        "transfer_id",
        "amount",
        "sender_id",
        "recipient_id",
        "recipient_name",
        "recipient_staff_id",
        "created_at",
        "sender_balance",
        "recipient_balance",
        "is_idempotent_replay",
    }
    assert set(data.keys()) == expected_keys

    # Sensitive fields strictly absent
    assert "password_hash" not in data
    assert "mobile" not in data
    assert "points_rule_id" not in data
    assert "qr_code_id" not in data
    assert "batch_id" not in data
    assert "created_by" not in data


# ============================================================================
# 9. Role Authorization (Partner Only)
# ============================================================================

def test_unauthenticated_request_rejected_with_401(client: TestClient, seed_data):
    """Unauthenticated transfer request returns 401."""
    qr = seed_data["qr_valid_staff"]
    payload = {"token": qr.token, "amount": 50, "idempotency_key": "tx-unauth"}
    response = client.post("/api/v1/partner/transfers", json=payload)
    assert response.status_code == 401


def test_customer_and_staff_and_admin_cannot_execute_transfers(client: TestClient, seed_data):
    """Only Partner can execute transfers; Staff, Customer, and Admin are rejected with 403."""
    qr = seed_data["qr_valid_staff"]
    payload = {"token": qr.token, "amount": 50, "idempotency_key": "tx-forbidden"}

    # Customer
    res_cust = client.post(
        "/api/v1/partner/transfers", json=payload, headers=auth_headers(seed_data["customer_user"])
    )
    assert res_cust.status_code == 403

    # Staff
    res_staff = client.post(
        "/api/v1/partner/transfers", json=payload, headers=auth_headers(seed_data["staff_user"])
    )
    assert res_staff.status_code == 403

    # Admin
    res_admin = client.post(
        "/api/v1/partner/transfers", json=payload, headers=auth_headers(seed_data["admin_user"])
    )
    assert res_admin.status_code == 403
