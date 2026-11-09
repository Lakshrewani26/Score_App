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
    token = create_access_token(subject=str(user.id), role=user.role, mobile=user.mobile)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def seed_data(db: Session):
    # Partners
    partner_1 = User(
        name="Apex Motors Partner",
        mobile="9800000001",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    partner_2 = User(
        name="Zenith Spares Partner",
        mobile="9800000002",
        password_hash=hash_password("Partner@123"),
        role="partner",
        is_active=True,
    )
    # Staff
    staff_user = User(
        name="Vikram Staff",
        mobile="9800000003",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    # Customer
    customer_user = User(
        name="Ramesh Customer",
        mobile="9800000004",
        password_hash=hash_password("Cust@123"),
        role="customer",
        is_active=True,
    )

    db.add_all([partner_1, partner_2, staff_user, customer_user])
    db.flush()

    partner_profile_1 = PartnerProfile(
        user_id=partner_1.id,
        business_name="Apex Motors Workshop",
        business_address="123 Industrial Area",
    )
    partner_profile_2 = PartnerProfile(
        user_id=partner_2.id,
        business_name="Zenith Auto Spares",
        business_address="456 Station Road",
    )
    staff_profile = StaffProfile(
        user_id=staff_user.id,
        staff_id="STF-001",
    )
    customer_profile = CustomerProfile(
        user_id=customer_user.id,
        city="Mumbai",
    )
    db.add_all([partner_profile_1, partner_profile_2, staff_profile, customer_profile])

    category = ProductCategory(name="Lubricants")
    db.add(category)
    db.flush()

    product = Product(
        category_id=category.id,
        product_code="ENG-OIL-4T",
        name="Premium 4T Engine Oil",
        vehicle_type="2-Wheeler",
    )
    db.add(product)
    db.flush()

    batch = QrBatch(
        batch_number="BATCH-PARTNER-2026-001",
        qr_type="product",
        quantity=100,
        status="active",
        created_by=partner_1.id,
    )
    db.add(batch)
    db.flush()

    rule = PointsRule(
        rule_name="Engine Oil Promotion",
        category="partner_qr_scan",
        points_awarded=50,
        is_active=True,
        is_current=True,
    )
    db.add(rule)
    db.commit()

    return {
        "partner_1": partner_1,
        "partner_2": partner_2,
        "staff": staff_user,
        "customer": customer_user,
        "product": product,
        "batch": batch,
        "rule": rule,
    }


def test_partner_history_authentication_and_authorization(client: TestClient, seed_data):
    partner_1 = seed_data["partner_1"]
    staff = seed_data["staff"]
    customer = seed_data["customer"]

    # 1. Unauthenticated request -> 401
    res = client.get("/api/v1/partner/points-history")
    assert res.status_code == 401

    # 2. Invalid bearer token -> 401
    bad_headers = {"Authorization": "Bearer not.a.valid.jwt.token"}
    res = client.get("/api/v1/partner/points-history", headers=bad_headers)
    assert res.status_code == 401

    # 3. Customer role forbidden -> 403
    res = client.get("/api/v1/partner/points-history", headers=auth_headers(customer))
    assert res.status_code == 403

    # 4. Staff role forbidden -> 403
    res = client.get("/api/v1/partner/points-history", headers=auth_headers(staff))
    assert res.status_code == 403

    # 5. Partner role succeeds -> 200
    res = client.get("/api/v1/partner/points-history", headers=auth_headers(partner_1))
    assert res.status_code == 200
    data = res.json()
    assert data["items"] == []
    assert data["total"] == 0
    assert data["page"] == 1
    assert data["total_pages"] == 0
    assert data["has_next"] is False
    assert data["has_prev"] is False


def test_partner_history_empty_state(client: TestClient, seed_data):
    partner_1 = seed_data["partner_1"]
    res = client.get("/api/v1/partner/points-history", headers=auth_headers(partner_1))
    assert res.status_code == 200
    body = res.json()
    assert body["items"] == []
    assert body["total"] == 0
    assert body["page"] == 1
    assert body["page_size"] == 20
    assert body["total_pages"] == 0
    assert body["has_next"] is False
    assert body["has_prev"] is False


def test_partner_history_qr_credits_and_transfer_debits(client: TestClient, db: Session, seed_data):
    partner_1 = seed_data["partner_1"]
    staff = seed_data["staff"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    now = datetime(2026, 11, 10, 10, 0, 0, tzinfo=timezone.utc)

    # 1. Partner scans a QR code -> +50 credits
    qr1 = QrCode(
        batch_id=batch.id,
        token="QR-PARTNER-CREDIT-1",
        code_data="https://score.app/qr?token=QR-PARTNER-CREDIT-1",
        qr_type="product",
        status="redeemed",
        points_awarded=50,
        redeemed_by=partner_1.id,
        redeemed_at=now,
    )
    db.add(qr1)
    db.flush()

    tx1 = PointTransaction(
        user_id=partner_1.id,
        qr_code_id=qr1.id,
        qr_token=qr1.token,
        points_rule_id=rule.id,
        points_awarded=50,
        qr_type="product",
        transaction_type="qr_scan",
        created_at=now,
    )
    db.add(tx1)

    # 2. Partner scans another QR code -> +100 credits 10 minutes later
    qr2 = QrCode(
        batch_id=batch.id,
        token="QR-PARTNER-CREDIT-2",
        code_data="https://score.app/qr?token=QR-PARTNER-CREDIT-2",
        qr_type="product",
        status="redeemed",
        points_awarded=100,
        redeemed_by=partner_1.id,
        redeemed_at=now + timedelta(minutes=10),
    )
    db.add(qr2)
    db.flush()

    tx2 = PointTransaction(
        user_id=partner_1.id,
        qr_code_id=qr2.id,
        qr_token=qr2.token,
        points_rule_id=rule.id,
        points_awarded=100,
        qr_type="product",
        transaction_type="qr_scan",
        created_at=now + timedelta(minutes=10),
    )
    db.add(tx2)

    # 3. Partner transfers 40 points to Staff -> -40 debit 20 minutes later
    transfer = PointTransfer(
        sender_id=partner_1.id,
        recipient_id=staff.id,
        amount=40,
        idempotency_key="transfer-idem-key-001",
        remarks="Staff incentive transfer",
        created_at=now + timedelta(minutes=20),
    )
    db.add(transfer)
    db.commit()

    # Query partner history
    res = client.get("/api/v1/partner/points-history", headers=auth_headers(partner_1))
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 3
    items = data["items"]

    # Check newest first: transfer (20 min), tx2 (10 min), tx1 (0 min)
    # Item 0: Transfer to staff (debit)
    assert items[0]["id"] == f"tr-{transfer.id}"
    assert items[0]["direction"] == "debit"
    assert items[0]["points"] == -40
    assert items[0]["amount"] == 40
    assert items[0]["transaction_type"] == "transfer_sent"
    assert items[0]["recipient_name"] == "Vikram Staff"
    assert items[0]["recipient_staff_id"] == "STF-001"
    assert "Vikram Staff" in items[0]["title"]
    assert items[0]["reference_id"] == "transfer-idem-key-001"

    # Item 1: QR scan credit (+100)
    assert items[1]["id"] == f"pt-{tx2.id}"
    assert items[1]["direction"] == "credit"
    assert items[1]["points"] == 100
    assert items[1]["amount"] == 100
    assert items[1]["transaction_type"] == "qr_scan"
    assert items[1]["reference_id"] == "QR-PARTNER-CREDIT-2"

    # Item 2: QR scan credit (+50)
    assert items[2]["id"] == f"pt-{tx1.id}"
    assert items[2]["direction"] == "credit"
    assert items[2]["points"] == 50
    assert items[2]["amount"] == 50
    assert items[2]["transaction_type"] == "qr_scan"
    assert items[2]["reference_id"] == "QR-PARTNER-CREDIT-1"

    # Verify mathematical balance consistency:
    # 50 + 100 - 40 = 110
    bal_summary = get_user_points_balance(db, partner_1.id, role="partner")
    assert bal_summary.current_balance == 110
    assert sum(it["points"] for it in items) == bal_summary.current_balance
    assert sum(it["amount"] for it in items if it["direction"] == "credit") == 150
    assert sum(it["amount"] for it in items if it["direction"] == "debit") == 40


def test_partner_data_isolation(client: TestClient, db: Session, seed_data):
    partner_1 = seed_data["partner_1"]
    partner_2 = seed_data["partner_2"]
    staff = seed_data["staff"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    # Add points and transfer for Partner 1
    qr1 = QrCode(
        batch_id=batch.id,
        token="QR-P1",
        code_data="https://score.app/qr?token=QR-P1",
        qr_type="product",
        status="redeemed",
        points_awarded=75,
        redeemed_by=partner_1.id,
    )
    db.add(qr1)
    db.flush()
    db.add(
        PointTransaction(
            user_id=partner_1.id,
            qr_code_id=qr1.id,
            qr_token=qr1.token,
            points_rule_id=rule.id,
            points_awarded=75,
            qr_type="product",
            transaction_type="qr_scan",
        )
    )
    db.add(
        PointTransfer(
            sender_id=partner_1.id,
            recipient_id=staff.id,
            amount=25,
            idempotency_key="p1-transfer-key",
        )
    )

    # Add points for Partner 2
    qr2 = QrCode(
        batch_id=batch.id,
        token="QR-P2",
        code_data="https://score.app/qr?token=QR-P2",
        qr_type="product",
        status="redeemed",
        points_awarded=200,
        redeemed_by=partner_2.id,
    )
    db.add(qr2)
    db.flush()
    db.add(
        PointTransaction(
            user_id=partner_2.id,
            qr_code_id=qr2.id,
            qr_token=qr2.token,
            points_rule_id=rule.id,
            points_awarded=200,
            qr_type="product",
            transaction_type="qr_scan",
        )
    )
    db.commit()

    # Partner 1 history: only see their own 2 transactions
    res1 = client.get("/api/v1/partner/points-history", headers=auth_headers(partner_1))
    assert res1.status_code == 200
    p1_items = res1.json()["items"]
    assert len(p1_items) == 2
    assert all("QR-P2" not in (it.get("reference_id") or "") for it in p1_items)
    assert sum(it["points"] for it in p1_items) == 50

    # Partner 2 history: only see their own 1 transaction
    res2 = client.get("/api/v1/partner/points-history", headers=auth_headers(partner_2))
    assert res2.status_code == 200
    p2_items = res2.json()["items"]
    assert len(p2_items) == 1
    assert p2_items[0]["points"] == 200
    assert p2_items[0]["reference_id"] == "QR-P2"


def test_partner_history_pagination_and_deterministic_order(client: TestClient, db: Session, seed_data):
    partner_1 = seed_data["partner_1"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    base_time = datetime(2026, 11, 10, 14, 0, 0, tzinfo=timezone.utc)

    # Create 12 transactions with deliberate shared timestamps to verify tie-breaking
    for i in range(12):
        qr = QrCode(
            batch_id=batch.id,
            token=f"TOKEN-PAGE-{i:03d}",
            code_data=f"https://score.app/qr?token=TOKEN-PAGE-{i:03d}",
            qr_type="product",
            status="redeemed",
            points_awarded=10 * (i + 1),
            redeemed_by=partner_1.id,
            redeemed_at=base_time + timedelta(minutes=i // 3),
        )
        db.add(qr)
        db.flush()
        db.add(
            PointTransaction(
                user_id=partner_1.id,
                qr_code_id=qr.id,
                qr_token=qr.token,
                points_rule_id=rule.id,
                points_awarded=10 * (i + 1),
                qr_type="product",
                transaction_type="qr_scan",
                created_at=base_time + timedelta(minutes=i // 3),
            )
        )
    db.commit()

    headers = auth_headers(partner_1)

    # Page 1 (size 5)
    p1 = client.get("/api/v1/partner/points-history?page=1&page_size=5", headers=headers).json()
    assert p1["total"] == 12
    assert len(p1["items"]) == 5
    assert p1["page"] == 1
    assert p1["total_pages"] == 3
    assert p1["has_next"] is True
    assert p1["has_prev"] is False

    # Page 2 (size 5)
    p2 = client.get("/api/v1/partner/points-history?page=2&page_size=5", headers=headers).json()
    assert p2["total"] == 12
    assert len(p2["items"]) == 5
    assert p2["page"] == 2
    assert p2["total_pages"] == 3
    assert p2["has_next"] is True
    assert p2["has_prev"] is True

    # Page 3 (size 5)
    p3 = client.get("/api/v1/partner/points-history?page=3&page_size=5", headers=headers).json()
    assert len(p3["items"]) == 2
    assert p3["page"] == 3
    assert p3["has_next"] is False
    assert p3["has_prev"] is True

    # Check distinct items across all pages (no duplicate ledger entries)
    all_ids = [it["id"] for it in p1["items"]] + [it["id"] for it in p2["items"]] + [it["id"] for it in p3["items"]]
    assert len(all_ids) == 12
    assert len(set(all_ids)) == 12

    # Verify descending created_at
    for p in [p1, p2]:
        for i in range(len(p["items"]) - 1):
            t1 = datetime.fromisoformat(p["items"][i]["created_at"])
            t2 = datetime.fromisoformat(p["items"][i + 1]["created_at"])
            assert t1 >= t2


def test_partner_alias_history_route(client: TestClient, seed_data):
    partner_1 = seed_data["partner_1"]
    # Test that /api/v1/partner/history alias works identically
    res = client.get("/api/v1/partner/history", headers=auth_headers(partner_1))
    assert res.status_code == 200
    assert res.json()["total"] == 0


def test_partner_balance_endpoint_and_consistency(client: TestClient, db: Session, seed_data):
    partner = seed_data["partner_1"]
    staff = seed_data["staff"]
    customer = seed_data["customer"]
    batch = seed_data["batch"]
    rule = seed_data["rule"]

    # 1. Unauthenticated -> 401
    assert client.get("/api/v1/partner/balance").status_code == 401
    assert client.get("/api/v1/partner/points/balance").status_code == 401

    # 2. Staff and Customer -> 403
    assert client.get("/api/v1/partner/balance", headers=auth_headers(staff)).status_code == 403
    assert client.get("/api/v1/partner/balance", headers=auth_headers(customer)).status_code == 403

    # 3. Setup transactions: 200 earned via QR, 60 transferred to Staff
    now = datetime(2026, 11, 10, 10, 0, 0, tzinfo=timezone.utc)
    qr = QrCode(
        batch_id=batch.id,
        token="QR-BAL-1",
        code_data="https://score.app/qr?token=QR-BAL-1",
        qr_type="product",
        status="redeemed",
        points_awarded=200,
        redeemed_by=partner.id,
        redeemed_at=now,
    )
    db.add(qr)
    db.flush()
    db.add(
        PointTransaction(
            user_id=partner.id,
            qr_code_id=qr.id,
            qr_token=qr.token,
            points_rule_id=rule.id,
            points_awarded=200,
            qr_type="product",
            transaction_type="qr_scan",
            created_at=now,
        )
    )
    db.add(
        PointTransfer(
            sender_id=partner.id,
            recipient_id=staff.id,
            amount=60,
            idempotency_key="bal-transfer-60",
            created_at=now + timedelta(minutes=15),
        )
    )
    db.commit()

    headers = auth_headers(partner)

    # 4. Check /partner/balance
    bal_res = client.get("/api/v1/partner/balance", headers=headers)
    assert bal_res.status_code == 200
    bal = bal_res.json()
    assert bal["points_earned"] == 200
    assert bal["points_spent"] == 60
    assert bal["current_balance"] == 140
    assert bal["total_earned_points"] == 200
    assert bal["total_spent_points"] == 60
    assert bal["remaining_balance"] == 140

    # 5. Check /orders/dashboard/stats
    stats_res = client.get("/api/v1/orders/dashboard/stats", headers=headers)
    assert stats_res.status_code == 200
    stats = stats_res.json()
    assert stats["total_points"] == 200
    assert stats["points_used"] == 60
    assert stats["remaining_balance"] == 140

    # 6. Check /partner/points-history
    hist_res = client.get("/api/v1/partner/points-history", headers=headers)
    assert hist_res.status_code == 200
    hist = hist_res.json()
    assert hist["total"] == 2

    credits = sum(it["amount"] for it in hist["items"] if it["direction"] == "credit")
    debits = sum(it["amount"] for it in hist["items"] if it["direction"] == "debit")
    net = sum(it["points"] for it in hist["items"])

    assert credits == bal["points_earned"] == stats["total_points"] == 200
    assert debits == bal["points_spent"] == stats["points_used"] == 60
    assert net == bal["current_balance"] == stats["remaining_balance"] == 140

