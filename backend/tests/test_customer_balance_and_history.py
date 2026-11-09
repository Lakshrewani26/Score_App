from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Generator
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
    PartnerProfile,
    PointTransaction,
    PointTransfer,
    PointsRule,
    Product,
    ProductCategory,
    QrBatch,
    QrCode,
    StaffProfile,
    User,
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


def auth_headers(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role=user.role, mobile=user.mobile)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def seed_data(db: Session):
    # 1. Users
    customer_1 = User(
        name="Ramesh Customer",
        mobile="9800000001",
        password_hash=hash_password("Cust@123"),
        role="customer",
        is_active=True,
    )
    customer_2 = User(
        name="Suresh Customer",
        mobile="9800000002",
        password_hash=hash_password("Cust@123"),
        role="customer",
        is_active=True,
    )
    partner_user = User(
        name="Apex Motors Partner",
        mobile="9800000003",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    staff_user = User(
        name="Rajesh Staff",
        mobile="9800000004",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    db.add_all([customer_1, customer_2, partner_user, staff_user])
    db.flush()

    # Profiles
    c1_profile = CustomerProfile(user_id=customer_1.id, state="MH", city="Pune", segment="2-Wheeler")
    c2_profile = CustomerProfile(user_id=customer_2.id, state="MH", city="Mumbai", segment="Both")
    p_profile = PartnerProfile(user_id=partner_user.id, business_name="Apex Motors", business_address="100 Auto Nagar", partner_code="PAR-APX")
    s_profile = StaffProfile(user_id=staff_user.id, staff_id="STF-001")
    db.add_all([c1_profile, c2_profile, p_profile, s_profile])

    # Category, Product, Batch, Rule
    cat = ProductCategory(name="Brakes")
    db.add(cat)
    db.flush()

    prod = Product(
        product_code="BRK-001",
        name="Disc Brake Pad",
        vehicle_type="2-Wheeler",
        category_id=cat.id,
        is_active=True,
    )
    batch = QrBatch(
        batch_number="BATCH-2026-001",
        qr_type="product",
        quantity=50,
        status="active",
        created_by=staff_user.id,
    )
    rule = PointsRule(
        rule_name="Customer Scan Loyalty Rule",
        category="customer_qr_scan",
        version=1,
        is_current=True,
        is_active=True,
        points_awarded=50,
    )
    transfer_rule = PointsRule(
        rule_name="Customer to Partner Transfer",
        category="customer_to_partner_transfer",
        version=1,
        is_current=True,
        is_active=True,
    )
    db.add_all([prod, batch, rule, transfer_rule])
    db.commit()

    return {
        "customer_1": customer_1,
        "customer_2": customer_2,
        "partner": partner_user,
        "staff": staff_user,
        "batch": batch,
        "rule": rule,
        "transfer_rule": transfer_rule,
        "product": prod,
    }


def test_empty_balance_and_empty_history(client: TestClient, seed_data):
    customer = seed_data["customer_1"]
    headers = auth_headers(customer)

    # 1. Balance endpoint
    bal_res = client.get("/api/v1/customer/balance", headers=headers)
    assert bal_res.status_code == 200
    bal_data = bal_res.json()
    assert bal_data["points_earned"] == 0
    assert bal_data["points_spent"] == 0
    assert bal_data["current_balance"] == 0
    assert bal_data["total_earned_points"] == 0
    assert bal_data["total_spent_points"] == 0
    assert bal_data["remaining_balance"] == 0

    # 2. History endpoint
    hist_res = client.get("/api/v1/customer/points-history", headers=headers)
    assert hist_res.status_code == 200
    hist_data = hist_res.json()
    assert hist_data["total"] == 0
    assert hist_data["items"] == []
    assert hist_data["page"] == 1
    assert hist_data["page_size"] == 20
    assert hist_data["total_pages"] == 0
    assert hist_data["has_next"] is False
    assert hist_data["has_prev"] is False


def test_earned_points_from_product_qr_scans(client: TestClient, db: Session, seed_data):
    customer = seed_data["customer_1"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    # Create 2 QR codes and point transactions
    now = datetime.now(timezone.utc)
    qr1 = QrCode(
        batch_id=batch.id,
        token="PRD-TOKEN-001",
        code_data="https://score.app/qr?token=PRD-TOKEN-001",
        qr_type="product",
        status="redeemed",
        points_awarded=50,
        redeemed_by=customer.id,
        redeemed_at=now - timedelta(minutes=10),
    )
    qr2 = QrCode(
        batch_id=batch.id,
        token="PRD-TOKEN-002",
        code_data="https://score.app/qr?token=PRD-TOKEN-002",
        qr_type="product",
        status="redeemed",
        points_awarded=75,
        redeemed_by=customer.id,
        redeemed_at=now - timedelta(minutes=5),
    )
    db.add_all([qr1, qr2])
    db.flush()

    tx1 = PointTransaction(
        user_id=customer.id,
        qr_code_id=qr1.id,
        qr_token=qr1.token,
        points_rule_id=rule.id,
        points_awarded=50,
        qr_type="product",
        transaction_type="qr_scan",
        created_at=now - timedelta(minutes=10),
    )
    tx2 = PointTransaction(
        user_id=customer.id,
        qr_code_id=qr2.id,
        qr_token=qr2.token,
        points_rule_id=rule.id,
        points_awarded=75,
        qr_type="product",
        transaction_type="qr_scan",
        created_at=now - timedelta(minutes=5),
    )
    db.add_all([tx1, tx2])
    db.commit()

    headers = auth_headers(customer)
    bal_res = client.get("/api/v1/customer/balance", headers=headers)
    assert bal_res.status_code == 200
    bal_data = bal_res.json()
    assert bal_data["points_earned"] == 125
    assert bal_data["points_spent"] == 0
    assert bal_data["current_balance"] == 125

    hist_res = client.get("/api/v1/customer/points-history", headers=headers)
    assert hist_res.status_code == 200
    hist_data = hist_res.json()
    assert hist_data["total"] == 2
    assert len(hist_data["items"]) == 2

    # Newest first
    assert hist_data["items"][0]["points"] == 75
    assert hist_data["items"][0]["direction"] == "credit"
    assert hist_data["items"][0]["reference_id"] == "PRD-TOKEN-002"

    assert hist_data["items"][1]["points"] == 50
    assert hist_data["items"][1]["direction"] == "credit"
    assert hist_data["items"][1]["reference_id"] == "PRD-TOKEN-001"


def test_spent_points_from_transfer_deductions(client: TestClient, db: Session, seed_data):
    customer = seed_data["customer_1"]
    partner = seed_data["partner"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]
    transfer_rule = seed_data["transfer_rule"]

    now = datetime.now(timezone.utc)
    # Give customer 200 points
    qr = QrCode(
        batch_id=batch.id,
        token="PRD-TOKEN-200",
        code_data="https://score.app/qr?token=PRD-TOKEN-200",
        qr_type="product",
        status="redeemed",
        points_awarded=200,
        redeemed_by=customer.id,
        redeemed_at=now - timedelta(hours=2),
    )
    db.add(qr)
    db.flush()

    tx = PointTransaction(
        user_id=customer.id,
        qr_code_id=qr.id,
        qr_token=qr.token,
        points_rule_id=rule.id,
        points_awarded=200,
        qr_type="product",
        transaction_type="qr_scan",
        created_at=now - timedelta(hours=2),
    )
    # Deduct 80 points via transfer to partner
    transfer = PointTransfer(
        sender_id=customer.id,
        recipient_id=partner.id,
        amount=80,
        points_rule_id=transfer_rule.id,
        idempotency_key="idemp-cust-part-001",
        remarks="Customer points transfer to Apex Motors",
        created_at=now - timedelta(hours=1),
    )
    db.add_all([tx, transfer])
    db.commit()

    headers = auth_headers(customer)
    bal_res = client.get("/api/v1/customer/balance", headers=headers)
    assert bal_res.status_code == 200
    bal = bal_res.json()
    assert bal["points_earned"] == 200
    assert bal["points_spent"] == 80
    assert bal["current_balance"] == 120

    hist_res = client.get("/api/v1/customer/points-history", headers=headers)
    assert hist_res.status_code == 200
    hist = hist_res.json()
    assert hist["total"] == 2

    # Newest is transfer (1 hour ago vs 2 hours ago)
    spent_item = hist["items"][0]
    assert spent_item["direction"] == "debit"
    assert spent_item["points"] == -80
    assert spent_item["amount"] == 80
    assert spent_item["recipient_name"] == "Apex Motors Partner"
    assert spent_item["transaction_type"] == "transfer_sent"

    earned_item = hist["items"][1]
    assert earned_item["direction"] == "credit"
    assert earned_item["points"] == 200
    assert earned_item["amount"] == 200


def test_balance_and_history_consistency(client: TestClient, db: Session, seed_data):
    customer = seed_data["customer_1"]
    partner = seed_data["partner"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    now = datetime.now(timezone.utc)
    # 3 earnings: 100, 50, 30
    for idx, pts in enumerate([100, 50, 30]):
        qr = QrCode(
            batch_id=batch.id,
            token=f"CONSIST-TOKEN-{idx}",
            code_data=f"https://score.app/qr?token=CONSIST-TOKEN-{idx}",
            qr_type="product",
            status="redeemed",
            points_awarded=pts,
            redeemed_by=customer.id,
            redeemed_at=now - timedelta(hours=3 - idx),
        )
        db.add(qr)
        db.flush()
        db.add(
            PointTransaction(
                user_id=customer.id,
                qr_code_id=qr.id,
                qr_token=qr.token,
                points_rule_id=rule.id,
                points_awarded=pts,
                qr_type="product",
                transaction_type="qr_scan",
                created_at=now - timedelta(hours=3 - idx),
            )
        )

    # 2 transfers: 40, 25
    db.add(
        PointTransfer(
            sender_id=customer.id,
            recipient_id=partner.id,
            amount=40,
            idempotency_key="idemp-consist-1",
            remarks="Transfer 1",
            created_at=now - timedelta(minutes=45),
        )
    )
    db.add(
        PointTransfer(
            sender_id=customer.id,
            recipient_id=partner.id,
            amount=25,
            idempotency_key="idemp-consist-2",
            remarks="Transfer 2",
            created_at=now - timedelta(minutes=15),
        )
    )
    db.commit()

    headers = auth_headers(customer)
    bal = client.get("/api/v1/customer/balance", headers=headers).json()
    hist = client.get("/api/v1/customer/points-history?page_size=50", headers=headers).json()

    # Mathematical consistency assertions
    total_earned_in_history = sum(item["amount"] for item in hist["items"] if item["direction"] == "credit")
    total_spent_in_history = sum(item["amount"] for item in hist["items"] if item["direction"] == "debit")
    net_in_history = sum(item["points"] for item in hist["items"])

    assert total_earned_in_history == bal["points_earned"] == 180
    assert total_spent_in_history == bal["points_spent"] == 65
    assert net_in_history == bal["current_balance"] == 115


def test_pagination_and_deterministic_ordering(client: TestClient, db: Session, seed_data):
    customer = seed_data["customer_1"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    base_time = datetime(2026, 11, 10, 12, 0, 0, tzinfo=timezone.utc)
    # Insert 15 transactions; some with identical timestamps to test deterministic tie-breaking
    for i in range(15):
        qr = QrCode(
            batch_id=batch.id,
            token=f"PAGE-TOKEN-{i:03d}",
            code_data=f"https://score.app/qr?token=PAGE-TOKEN-{i:03d}",
            qr_type="product",
            status="redeemed",
            points_awarded=10 + i,
            redeemed_by=customer.id,
            redeemed_at=base_time + timedelta(minutes=i // 3),  # groups of 3 have identical timestamp
        )
        db.add(qr)
        db.flush()
        db.add(
            PointTransaction(
                user_id=customer.id,
                qr_code_id=qr.id,
                qr_token=qr.token,
                points_rule_id=rule.id,
                points_awarded=10 + i,
                qr_type="product",
                transaction_type="qr_scan",
                created_at=base_time + timedelta(minutes=i // 3),
            )
        )
    db.commit()

    headers = auth_headers(customer)

    # Page 1 (size 6)
    p1 = client.get("/api/v1/customer/points-history?page=1&page_size=6", headers=headers).json()
    assert p1["total"] == 15
    assert len(p1["items"]) == 6
    assert p1["page"] == 1
    assert p1["total_pages"] == 3
    assert p1["has_next"] is True
    assert p1["has_prev"] is False

    # Page 2 (size 6)
    p2 = client.get("/api/v1/customer/points-history?page=2&page_size=6", headers=headers).json()
    assert p2["total"] == 15
    assert len(p2["items"]) == 6
    assert p2["page"] == 2
    assert p2["total_pages"] == 3
    assert p2["has_next"] is True
    assert p2["has_prev"] is True

    # Page 3 (size 6)
    p3 = client.get("/api/v1/customer/points-history?page=3&page_size=6", headers=headers).json()
    assert len(p3["items"]) == 3
    assert p3["page"] == 3
    assert p3["has_next"] is False
    assert p3["has_prev"] is True

    # Deterministic disjoint items: no duplicates across pages
    all_ids = [it["id"] for it in p1["items"]] + [it["id"] for it in p2["items"]] + [it["id"] for it in p3["items"]]
    assert len(all_ids) == 15
    assert len(set(all_ids)) == 15

    # Check newest first
    for i in range(len(p1["items"]) - 1):
        t1 = datetime.fromisoformat(p1["items"][i]["created_at"])
        t2 = datetime.fromisoformat(p1["items"][i + 1]["created_at"])
        assert t1 >= t2


def test_customer_endpoints_unauthorized_access(client: TestClient, seed_data):
    partner = seed_data["partner"]
    staff = seed_data["staff"]

    # 1. No token -> 401
    assert client.get("/api/v1/customer/balance").status_code == 401
    assert client.get("/api/v1/customer/points-history").status_code == 401

    # 2. Invalid bearer token -> 401
    bad_headers = {"Authorization": "Bearer invalid.jwt.token"}
    assert client.get("/api/v1/customer/balance", headers=bad_headers).status_code == 401
    assert client.get("/api/v1/customer/points-history", headers=bad_headers).status_code == 401

    # 3. Partner caller -> 403 Forbidden
    assert client.get("/api/v1/customer/balance", headers=auth_headers(partner)).status_code == 403
    assert client.get("/api/v1/customer/points-history", headers=auth_headers(partner)).status_code == 403

    # 4. Staff caller -> 403 Forbidden
    assert client.get("/api/v1/customer/balance", headers=auth_headers(staff)).status_code == 403
    assert client.get("/api/v1/customer/points-history", headers=auth_headers(staff)).status_code == 403


def test_customer_data_isolation(client: TestClient, db: Session, seed_data):
    c1 = seed_data["customer_1"]
    c2 = seed_data["customer_2"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    now = datetime.now(timezone.utc)
    # Customer 1 earns 100
    qr1 = QrCode(
        batch_id=batch.id,
        token="CUST1-TOKEN",
        code_data="https://score.app/qr?token=CUST1-TOKEN",
        qr_type="product",
        status="redeemed",
        points_awarded=100,
        redeemed_by=c1.id,
        redeemed_at=now,
    )
    db.add(qr1)
    db.flush()
    db.add(
        PointTransaction(
            user_id=c1.id,
            qr_code_id=qr1.id,
            qr_token=qr1.token,
            points_rule_id=rule.id,
            points_awarded=100,
            qr_type="product",
            transaction_type="qr_scan",
            created_at=now,
        )
    )

    # Customer 2 earns 300
    qr2 = QrCode(
        batch_id=batch.id,
        token="CUST2-TOKEN",
        code_data="https://score.app/qr?token=CUST2-TOKEN",
        qr_type="product",
        status="redeemed",
        points_awarded=300,
        redeemed_by=c2.id,
        redeemed_at=now,
    )
    db.add(qr2)
    db.flush()
    db.add(
        PointTransaction(
            user_id=c2.id,
            qr_code_id=qr2.id,
            qr_token=qr2.token,
            points_rule_id=rule.id,
            points_awarded=300,
            qr_type="product",
            transaction_type="qr_scan",
            created_at=now,
        )
    )
    db.commit()

    # C1 receives only C1 data
    c1_bal = client.get("/api/v1/customer/balance", headers=auth_headers(c1)).json()
    assert c1_bal["current_balance"] == 100
    c1_hist = client.get("/api/v1/customer/points-history", headers=auth_headers(c1)).json()
    assert c1_hist["total"] == 1
    assert c1_hist["items"][0]["reference_id"] == "CUST1-TOKEN"

    # C2 receives only C2 data
    c2_bal = client.get("/api/v1/customer/balance", headers=auth_headers(c2)).json()
    assert c2_bal["current_balance"] == 300
    c2_hist = client.get("/api/v1/customer/points-history", headers=auth_headers(c2)).json()
    assert c2_hist["total"] == 1
    assert c2_hist["items"][0]["reference_id"] == "CUST2-TOKEN"

    # Query param tampering cannot breach isolation
    c1_tampered = client.get(
        f"/api/v1/customer/balance?user_id={c2.id}",
        headers=auth_headers(c1),
    ).json()
    assert c1_tampered["current_balance"] == 100


def test_legacy_qr_fallback_behavior(client: TestClient, db: Session, seed_data):
    customer = seed_data["customer_1"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    now = datetime.now(timezone.utc)

    # 1. A legacy redeemed QR code exists with points_awarded=45, but NO PointTransaction
    legacy_qr = QrCode(
        batch_id=batch.id,
        token="LEGACY-UNLINKED-QR",
        code_data="https://score.app/qr?token=LEGACY-UNLINKED-QR",
        qr_type="product",
        status="redeemed",
        points_awarded=45,
        redeemed_by=customer.id,
        redeemed_at=now - timedelta(days=2),
    )
    db.add(legacy_qr)
    db.commit()

    headers = auth_headers(customer)
    bal1 = client.get("/api/v1/customer/balance", headers=headers).json()
    assert bal1["points_earned"] == 45
    assert bal1["current_balance"] == 45

    hist1 = client.get("/api/v1/customer/points-history", headers=headers).json()
    assert hist1["total"] == 1
    assert hist1["items"][0]["reference_id"] == "LEGACY-UNLINKED-QR"
    assert hist1["items"][0]["points"] == 45

    # 2. Now add a PointTransaction linked to a new QR
    new_qr = QrCode(
        batch_id=batch.id,
        token="MODERN-LINKED-QR",
        code_data="https://score.app/qr?token=MODERN-LINKED-QR",
        qr_type="product",
        status="redeemed",
        points_awarded=55,
        redeemed_by=customer.id,
        redeemed_at=now - timedelta(days=1),
    )
    db.add(new_qr)
    db.flush()
    db.add(
        PointTransaction(
            user_id=customer.id,
            qr_code_id=new_qr.id,
            qr_token=new_qr.token,
            points_rule_id=rule.id,
            points_awarded=55,
            qr_type="product",
            transaction_type="qr_scan",
            created_at=now - timedelta(days=1),
        )
    )
    db.commit()

    # Total must be 45 (legacy) + 55 (modern) = 100 without double counting
    bal2 = client.get("/api/v1/customer/balance", headers=headers).json()
    assert bal2["points_earned"] == 100
    assert bal2["current_balance"] == 100

    hist2 = client.get("/api/v1/customer/points-history", headers=headers).json()
    assert hist2["total"] == 2
    ref_ids = {it["reference_id"] for it in hist2["items"]}
    assert ref_ids == {"LEGACY-UNLINKED-QR", "MODERN-LINKED-QR"}
