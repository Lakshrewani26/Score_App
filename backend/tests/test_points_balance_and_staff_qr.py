from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Generator
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
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
from app.services.points_service import (
    calculate_user_balance,
    get_user_points_balance,
    get_users_points_balances,
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


@pytest.fixture
def seed_data(db: Session):
    # 1. Users
    partner_user = User(
        name="Apex Motors Partner",
        mobile="9811111111",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    partner_user_2 = User(
        name="Metro Spares Partner",
        mobile="9811111112",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    staff_user_1 = User(
        name="Rajesh Kumar Staff",
        mobile="9822222221",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    staff_user_2 = User(
        name="Amit Singh Staff",
        mobile="9822222222",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    staff_without_qr = User(
        name="Pooja Sharma Staff",
        mobile="9822222223",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
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
        partner_user_2,
        staff_user_1,
        staff_user_2,
        staff_without_qr,
        customer_user,
        admin_user,
    ])
    db.flush()

    # Profiles
    p1_profile = PartnerProfile(
        user_id=partner_user.id,
        business_name="Apex Motors",
        business_address="100 Auto Nagar",
        partner_code="PAR-APX",
    )
    p2_profile = PartnerProfile(
        user_id=partner_user_2.id,
        business_name="Metro Spares",
        business_address="200 Ring Road",
        partner_code="PAR-MTR",
    )
    s1_profile = StaffProfile(
        user_id=staff_user_1.id,
        staff_id="STF-001",
    )
    s2_profile = StaffProfile(
        user_id=staff_user_2.id,
        staff_id="STF-002",
    )
    s3_profile = StaffProfile(
        user_id=staff_without_qr.id,
        staff_id="STF-003",
    )
    c_profile = CustomerProfile(
        user_id=customer_user.id,
        state="Maharashtra",
        city="Pune",
        segment="Retail",
    )
    assignment = StaffPartnerAssignment(
        staff_id=staff_user_1.id,
        partner_id=partner_user.id,
        is_active=True,
    )
    db.add_all([p1_profile, p2_profile, s1_profile, s2_profile, s3_profile, c_profile, assignment])
    db.flush()

    # Rules
    rule_partner_scan = PointsRule(
        rule_name="Partner QR Scan Loyalty",
        category="partner_qr_scan",
        points_awarded=50,
        is_active=True,
        is_current=True,
        version=1,
    )
    rule_customer_scan = PointsRule(
        rule_name="Customer QR Scan Loyalty",
        category="customer_qr_scan",
        points_awarded=25,
        is_active=True,
        is_current=True,
        version=1,
    )
    rule_transfer = PointsRule(
        rule_name="Partner to Staff Transfer Incentive",
        category="partner_to_staff_transfer",
        points_awarded=100,
        is_active=True,
        is_current=True,
        version=1,
    )
    db.add_all([rule_partner_scan, rule_customer_scan, rule_transfer])
    db.flush()

    # QR Batches and Codes
    batch_staff = QrBatch(
        batch_number="BATCH-STF-001",
        qr_type="staff",
        quantity=2,
        created_by=admin_user.id,
    )
    category = ProductCategory(name="Brakes", is_active=True)
    db.add_all([batch_staff, category])
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

    batch_product = QrBatch(
        batch_number="BATCH-PRD-001",
        qr_type="product",
        quantity=5,
        product_id=product.id,
        created_by=admin_user.id,
    )
    db.add(batch_product)
    db.flush()

    # Staff QR codes
    qr_staff_1 = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF1_QR_TOKEN_X9Y8Z7",
        code_data="score://qr/v1?token=STAFF1_QR_TOKEN_X9Y8Z7&type=staff",
        target_user_id=staff_user_1.id,
        points_awarded=100,
        status="active",
    )
    qr_staff_2 = QrCode(
        batch_id=batch_staff.id,
        qr_type="staff",
        token="STAFF2_QR_TOKEN_A1B2C3",
        code_data="score://qr/v1?token=STAFF2_QR_TOKEN_A1B2C3&type=staff",
        target_user_id=staff_user_2.id,
        points_awarded=100,
        status="active",
    )
    # Product QR codes for scanning
    qr_prod_1 = QrCode(
        batch_id=batch_product.id,
        qr_type="product",
        token="PROD_TOKEN_P1_00000000000001",
        code_data="score://qr/v1?token=PROD_TOKEN_P1_00000000000001&type=product",
        product_id=product.id,
        status="active",
    )
    qr_prod_2 = QrCode(
        batch_id=batch_product.id,
        qr_type="product",
        token="PROD_TOKEN_P2_00000000000002",
        code_data="score://qr/v1?token=PROD_TOKEN_P2_00000000000002&type=product",
        product_id=product.id,
        status="active",
    )
    qr_prod_3 = QrCode(
        batch_id=batch_product.id,
        qr_type="product",
        token="PROD_TOKEN_P3_00000000000003",
        code_data="score://qr/v1?token=PROD_TOKEN_P3_00000000000003&type=product",
        product_id=product.id,
        status="active",
    )
    db.add_all([qr_staff_1, qr_staff_2, qr_prod_1, qr_prod_2, qr_prod_3])
    db.commit()

    return {
        "partner_1": partner_user,
        "partner_2": partner_user_2,
        "staff_1": staff_user_1,
        "staff_2": staff_user_2,
        "staff_without_qr": staff_without_qr,
        "customer": customer_user,
        "admin": admin_user,
        "rule_partner_scan": rule_partner_scan,
        "rule_customer_scan": rule_customer_scan,
        "rule_transfer": rule_transfer,
        "qr_staff_1": qr_staff_1,
        "qr_staff_2": qr_staff_2,
        "qr_prod_1": qr_prod_1,
        "qr_prod_2": qr_prod_2,
        "qr_prod_3": qr_prod_3,
    }


def auth_headers(user: User) -> dict[str, str]:
    token = create_access_token(
        subject=str(user.id),
        role=user.role,
        mobile=user.mobile,
    )
    return {"Authorization": f"Bearer {token}"}


# ==============================================================================
# SECTION A: UNIFIED POINTS BALANCE SERVICE TESTS
# ==============================================================================


def test_partner_balance_with_earned_points_and_sent_transfers(db: Session, seed_data):
    partner = seed_data["partner_1"]
    staff = seed_data["staff_1"]
    rule = seed_data["rule_partner_scan"]
    transfer_rule = seed_data["rule_transfer"]
    qr = seed_data["qr_prod_1"]

    # 1. Initial balance is 0
    bal_initial = get_user_points_balance(db, partner.id, role="partner")
    assert bal_initial.points_earned == 0
    assert bal_initial.transfers_sent == 0
    assert bal_initial.transfers_received == 0
    assert bal_initial.current_balance == 0

    # 2. Partner earns 300 points from QR scans
    tx1 = PointTransaction(
        user_id=partner.id,
        qr_code_id=qr.id,
        qr_token=qr.token,
        points_rule_id=rule.id,
        points_awarded=300,
        qr_type="product",
        transaction_type="qr_scan",
    )
    db.add(tx1)
    db.commit()

    bal_after_earn = get_user_points_balance(db, partner.id, role="partner")
    assert bal_after_earn.points_earned == 300
    assert bal_after_earn.transfers_sent == 0
    assert bal_after_earn.current_balance == 300

    # 3. Partner transfers 120 points to Staff
    t1 = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=120,
        points_rule_id=transfer_rule.id,
        idempotency_key="transfer-partner-test-01",
    )
    db.add(t1)
    db.commit()

    bal_after_t1 = get_user_points_balance(db, partner.id, role="partner")
    assert bal_after_t1.points_earned == 300
    assert bal_after_t1.transfers_sent == 120
    assert bal_after_t1.points_spent == 120
    assert bal_after_t1.current_balance == 180
    assert calculate_user_balance(db, partner.id) == 180

    # 4. Partner sends another transfer of 50 points
    t2 = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=50,
        points_rule_id=transfer_rule.id,
        idempotency_key="transfer-partner-test-02",
    )
    db.add(t2)
    db.commit()

    bal_after_t2 = get_user_points_balance(db, partner.id, role="partner")
    assert bal_after_t2.points_earned == 300
    assert bal_after_t2.transfers_sent == 170
    assert bal_after_t2.points_spent == 170
    assert bal_after_t2.current_balance == 130


def test_staff_balance_with_received_transfers(db: Session, seed_data):
    partner_1 = seed_data["partner_1"]
    partner_2 = seed_data["partner_2"]
    staff = seed_data["staff_1"]
    transfer_rule = seed_data["rule_transfer"]
    qr_staff = seed_data["qr_staff_1"]

    # 1. Staff initially has 0 balance
    staff_bal_initial = get_user_points_balance(db, staff.id, role="staff")
    assert staff_bal_initial.points_earned == 0
    assert staff_bal_initial.transfers_received == 0
    assert staff_bal_initial.current_balance == 0

    # 2. Partner 1 transfers 200 points to Staff
    t1 = PointTransfer(
        sender_id=partner_1.id,
        recipient_id=staff.id,
        amount=200,
        points_rule_id=transfer_rule.id,
        qr_code_id=qr_staff.id,
        idempotency_key="tx-staff-recv-001",
    )
    # 3. Partner 2 transfers 150 points to Staff
    t2 = PointTransfer(
        sender_id=partner_2.id,
        recipient_id=staff.id,
        amount=150,
        points_rule_id=transfer_rule.id,
        qr_code_id=qr_staff.id,
        idempotency_key="tx-staff-recv-002",
    )
    db.add_all([t1, t2])
    db.commit()

    staff_bal = get_user_points_balance(db, staff.id, role="staff")
    assert staff_bal.points_earned == 0
    assert staff_bal.transfers_received == 350
    assert staff_bal.transfers_sent == 0
    assert staff_bal.current_balance == 350
    assert isinstance(staff_bal.current_balance, int)


def test_customer_balance_preserves_existing_behavior(db: Session, seed_data):
    customer = seed_data["customer"]
    rule = seed_data["rule_customer_scan"]
    qr1 = seed_data["qr_prod_1"]
    qr2 = seed_data["qr_prod_2"]

    # Customer initially 0
    assert calculate_user_balance(db, customer.id) == 0

    # Customer scans qr1 (awards 25)
    tx1 = PointTransaction(
        user_id=customer.id,
        qr_code_id=qr1.id,
        qr_token=qr1.token,
        points_rule_id=rule.id,
        points_awarded=25,
        qr_type="product",
    )
    # Customer scans qr2 (awards 50)
    tx2 = PointTransaction(
        user_id=customer.id,
        qr_code_id=qr2.id,
        qr_token=qr2.token,
        points_rule_id=rule.id,
        points_awarded=50,
        qr_type="product",
    )
    db.add_all([tx1, tx2])
    db.commit()

    bal = get_user_points_balance(db, customer.id, role="customer")
    assert bal.points_earned == 75
    assert bal.transfers_sent == 0
    assert bal.transfers_received == 0
    assert bal.current_balance == 75
    assert calculate_user_balance(db, customer.id) == 75


def test_supported_deductions_reduce_balance(db: Session, seed_data):
    partner = seed_data["partner_1"]
    staff = seed_data["staff_1"]
    rule = seed_data["rule_partner_scan"]
    qr = seed_data["qr_prod_1"]

    tx = PointTransaction(
        user_id=partner.id,
        qr_code_id=qr.id,
        qr_token=qr.token,
        points_rule_id=rule.id,
        points_awarded=500,
        qr_type="product",
    )
    db.add(tx)
    db.commit()

    # Deduct 150 points via transfer
    t = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=150,
        idempotency_key="deduction-check-001",
    )
    db.add(t)
    db.commit()

    summary = get_user_points_balance(db, partner.id, role="partner")
    assert summary.points_spent == 150
    assert summary.current_balance == 350
    assert isinstance(summary.points_spent, int)
    assert isinstance(summary.current_balance, int)


def test_get_users_points_balances_batch_query(db: Session, seed_data):
    partner = seed_data["partner_1"]
    staff = seed_data["staff_1"]
    customer = seed_data["customer"]
    rule_p = seed_data["rule_partner_scan"]
    rule_c = seed_data["rule_customer_scan"]
    qr1 = seed_data["qr_prod_1"]
    qr2 = seed_data["qr_prod_2"]

    # Partner earns 400
    db.add(PointTransaction(
        user_id=partner.id,
        qr_code_id=qr1.id,
        qr_token=qr1.token,
        points_rule_id=rule_p.id,
        points_awarded=400,
        qr_type="product",
    ))
    # Customer earns 100
    db.add(PointTransaction(
        user_id=customer.id,
        qr_code_id=qr2.id,
        qr_token=qr2.token,
        points_rule_id=rule_c.id,
        points_awarded=100,
        qr_type="product",
    ))
    # Partner transfers 150 to Staff
    db.add(PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=150,
        idempotency_key="batch-test-tx-001",
    ))
    db.commit()

    batch_res = get_users_points_balances(db, [partner.id, staff.id, customer.id])
    assert len(batch_res) == 3

    p_sum = batch_res[partner.id]
    assert p_sum.points_earned == 400
    assert p_sum.transfers_sent == 150
    assert p_sum.current_balance == 250

    s_sum = batch_res[staff.id]
    assert s_sum.points_earned == 0
    assert s_sum.transfers_received == 150
    assert s_sum.current_balance == 150

    c_sum = batch_res[customer.id]
    assert c_sum.points_earned == 100
    assert c_sum.transfers_sent == 0
    assert c_sum.current_balance == 100


def test_partner_dashboard_stats_endpoint(client: TestClient, db: Session, seed_data):
    partner = seed_data["partner_1"]
    staff = seed_data["staff_1"]
    rule = seed_data["rule_partner_scan"]
    qr = seed_data["qr_prod_1"]

    # 1. Partner has 600 points from scan
    db.add(PointTransaction(
        user_id=partner.id,
        qr_code_id=qr.id,
        qr_token=qr.token,
        points_rule_id=rule.id,
        points_awarded=600,
        qr_type="product",
    ))
    # 2. Partner transfers 250 points to Staff
    db.add(PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=250,
        idempotency_key="tx-partner-dashboard-test",
    ))
    db.commit()

    res = client.get("/api/v1/orders/dashboard/stats", headers=auth_headers(partner))
    assert res.status_code == 200
    body = res.json()
    assert body["total_points"] == 600
    assert body["points_used"] == 250
    assert body["remaining_balance"] == 350


def test_staff_dashboard_stats_endpoint(client: TestClient, db: Session, seed_data):
    partner = seed_data["partner_1"]
    staff = seed_data["staff_1"]

    # Transfer 320 points to staff
    db.add(PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=320,
        idempotency_key="tx-staff-dashboard-test",
    ))
    db.commit()

    # Staff balance query via unified service
    staff_bal = get_user_points_balance(db, staff.id, role="staff")
    assert staff_bal.transfers_received == 320
    assert staff_bal.current_balance == 320

    res = client.get("/api/v1/staff/dashboard", headers=auth_headers(staff))
    assert res.status_code == 200
    body = res.json()
    assert body["dealers_count"] == 1
    assert "pending_orders_count" in body
    assert "pending_payments_count" in body


def test_qr_scan_updates_new_balance_consistently_after_transfers(
    client: TestClient, db: Session, seed_data
):
    partner = seed_data["partner_1"]
    staff = seed_data["staff_1"]
    qr_to_scan = seed_data["qr_prod_3"]

    # 1. Partner starts with 200 points in PointTransaction
    qr_prev = seed_data["qr_prod_1"]
    db.add(PointTransaction(
        user_id=partner.id,
        qr_code_id=qr_prev.id,
        qr_token=qr_prev.token,
        points_rule_id=seed_data["rule_partner_scan"].id,
        points_awarded=200,
        qr_type="product",
    ))
    # 2. Partner sent 50 points to Staff
    db.add(PointTransfer(
        sender_id=partner.id,
        recipient_id=staff.id,
        amount=50,
        idempotency_key="tx-qr-scan-balance-consistency",
    ))
    db.commit()

    # 3. Partner scans a new QR code worth 50 points
    res = client.post(
        "/api/v1/qr/scan",
        json={"token": qr_to_scan.token},
        headers=auth_headers(partner),
    )
    assert res.status_code == 200
    body = res.json()
    assert body["points_awarded"] == 50
    # Expected balance: 200 (prior) - 50 (sent transfer) + 50 (new scan) = 200
    assert body["new_balance"] == 200


# ==============================================================================
# SECTION B: STAFF QR RETRIEVAL ENDPOINT TESTS
# ==============================================================================


def test_staff_retrieves_own_assigned_qr(client: TestClient, seed_data):
    staff_1 = seed_data["staff_1"]
    qr_1 = seed_data["qr_staff_1"]

    res = client.get("/api/v1/staff/qr", headers=auth_headers(staff_1))
    assert res.status_code == 200
    data = res.json()

    assert data["id"] == qr_1.id
    assert data["qr_type"] == "staff"
    assert data["token"] == qr_1.token
    assert data["code_data"] == qr_1.code_data
    assert data["status"] == "active"
    assert data["target_user_id"] == staff_1.id
    assert data["points_awarded"] == 100
    assert "created_at" in data

    # Verify alias path /api/v1/staff/qr-code returns identical data
    res_alias = client.get("/api/v1/staff/qr-code", headers=auth_headers(staff_1))
    assert res_alias.status_code == 200
    assert res_alias.json()["token"] == qr_1.token


def test_staff_cannot_retrieve_another_users_qr(client: TestClient, seed_data):
    staff_1 = seed_data["staff_1"]
    staff_2 = seed_data["staff_2"]
    qr_1 = seed_data["qr_staff_1"]
    qr_2 = seed_data["qr_staff_2"]

    # 1. Staff 1 only receives QR 1
    res1 = client.get("/api/v1/staff/qr", headers=auth_headers(staff_1))
    assert res1.status_code == 200
    assert res1.json()["token"] == qr_1.token
    assert res1.json()["token"] != qr_2.token

    # 2. Staff 2 only receives QR 2
    res2 = client.get("/api/v1/staff/qr", headers=auth_headers(staff_2))
    assert res2.status_code == 200
    assert res2.json()["token"] == qr_2.token
    assert res2.json()["token"] != qr_1.token

    # 3. Supplying arbitrary user ID parameters cannot access another user's QR
    res_tamper = client.get(
        f"/api/v1/staff/qr?user_id={staff_2.id}&target_user_id={staff_2.id}",
        headers=auth_headers(staff_1),
    )
    assert res_tamper.status_code == 200
    # Still returns Staff 1's QR!
    assert res_tamper.json()["target_user_id"] == staff_1.id
    assert res_tamper.json()["token"] == qr_1.token


def test_staff_without_assigned_qr_receives_404(client: TestClient, seed_data):
    staff_no_qr = seed_data["staff_without_qr"]

    res = client.get("/api/v1/staff/qr", headers=auth_headers(staff_no_qr))
    assert res.status_code == 404
    assert res.json()["detail"] == "Staff QR code not found."


def test_staff_with_voided_or_expired_qr_receives_404(
    client: TestClient, db: Session, seed_data
):
    staff_1 = seed_data["staff_1"]
    qr_1 = seed_data["qr_staff_1"]

    # Void the QR code
    qr_1.status = "voided"
    db.commit()

    res_voided = client.get("/api/v1/staff/qr", headers=auth_headers(staff_1))
    assert res_voided.status_code == 404
    assert res_voided.json()["detail"] == "Staff QR code not found."

    # Now make it active but expired
    qr_1.status = "active"
    qr_1.expires_at = datetime.now(timezone.utc) - timedelta(days=1)
    db.commit()

    res_expired = client.get("/api/v1/staff/qr", headers=auth_headers(staff_1))
    assert res_expired.status_code == 404
    assert res_expired.json()["detail"] == "Staff QR code not found."


def test_non_staff_users_cannot_access_staff_qr_endpoint(client: TestClient, seed_data):
    partner = seed_data["partner_1"]
    customer = seed_data["customer"]

    # 1. Unauthenticated request
    res_unauth = client.get("/api/v1/staff/qr")
    assert res_unauth.status_code == 401

    # 2. Partner caller
    res_partner = client.get("/api/v1/staff/qr", headers=auth_headers(partner))
    assert res_partner.status_code == 403

    # 3. Customer caller
    res_customer = client.get("/api/v1/staff/qr", headers=auth_headers(customer))
    assert res_customer.status_code == 403


def test_staff_qr_does_not_auto_generate_or_expose_admin_internals(
    client: TestClient, db: Session, seed_data
):
    staff_no_qr = seed_data["staff_without_qr"]

    count_before = db.scalar(select(QrCode.id).where(QrCode.target_user_id == staff_no_qr.id))
    assert count_before is None

    # Call endpoint when no QR exists
    res = client.get("/api/v1/staff/qr", headers=auth_headers(staff_no_qr))
    assert res.status_code == 404

    # Confirm no new QR was generated
    count_after = db.scalar(select(QrCode.id).where(QrCode.target_user_id == staff_no_qr.id))
    assert count_after is None

    # For staff with QR, confirm sensitive admin fields are excluded
    staff_1 = seed_data["staff_1"]
    res_with_qr = client.get("/api/v1/staff/qr", headers=auth_headers(staff_1))
    assert res_with_qr.status_code == 200
    data = res_with_qr.json()
    assert "batch_id" not in data
    assert "redeemed_by" not in data
    assert "redeemed_at" not in data
    assert "created_by" not in data
