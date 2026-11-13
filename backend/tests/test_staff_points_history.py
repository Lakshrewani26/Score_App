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
    # Staff A & B
    staff_a = User(
        name="Vikram Staff",
        mobile="9800000003",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    staff_b = User(
        name="Rahul Staff",
        mobile="9800000004",
        password_hash=hash_password("Staff@123"),
        role="staff",
        is_active=True,
    )
    # Customer
    customer = User(
        name="Ramesh Customer",
        mobile="9800000005",
        password_hash=hash_password("Cust@123"),
        role="customer",
        is_active=True,
    )

    db.add_all([partner_1, partner_2, staff_a, staff_b, customer])
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
    staff_profile_a = StaffProfile(
        user_id=staff_a.id,
        staff_id="STF-001",
    )
    staff_profile_b = StaffProfile(
        user_id=staff_b.id,
        staff_id="STF-002",
    )
    customer_profile = CustomerProfile(
        user_id=customer.id,
        city="Mumbai",
    )
    db.add_all([partner_profile_1, partner_profile_2, staff_profile_a, staff_profile_b, customer_profile])
    db.commit()

    return {
        "partner_1": partner_1,
        "partner_2": partner_2,
        "staff_a": staff_a,
        "staff_b": staff_b,
        "customer": customer,
    }


def test_staff_endpoints_require_authentication(client: TestClient):
    """Staff balance and points history endpoints require valid Bearer token."""
    res_bal = client.get("/api/v1/staff/balance")
    assert res_bal.status_code == 401

    res_hist = client.get("/api/v1/staff/points-history")
    assert res_hist.status_code == 401


def test_customer_and_partner_cannot_access_staff_endpoints(client: TestClient, seed_data):
    """Customer and Partner roles are forbidden (403) from Staff endpoints."""
    customer = seed_data["customer"]
    partner = seed_data["partner_1"]

    cust_headers = auth_headers(customer)
    part_headers = auth_headers(partner)

    # Customer forbidden
    assert client.get("/api/v1/staff/balance", headers=cust_headers).status_code == 403
    assert client.get("/api/v1/staff/points-history", headers=cust_headers).status_code == 403

    # Partner forbidden
    assert client.get("/api/v1/staff/balance", headers=part_headers).status_code == 403
    assert client.get("/api/v1/staff/points-history", headers=part_headers).status_code == 403


def test_empty_staff_history_and_balance(client: TestClient, seed_data):
    """Staff with no transfers receives an honest empty response and zero balance."""
    staff_a = seed_data["staff_a"]
    headers = auth_headers(staff_a)

    res_bal = client.get("/api/v1/staff/balance", headers=headers)
    assert res_bal.status_code == 200
    bal_data = res_bal.json()
    assert bal_data["points_earned"] == 0
    assert bal_data["points_spent"] == 0
    assert bal_data["current_balance"] == 0

    res_hist = client.get("/api/v1/staff/points-history", headers=headers)
    assert res_hist.status_code == 200
    hist_data = res_hist.json()
    assert hist_data["items"] == []
    assert hist_data["total"] == 0
    assert hist_data["page"] == 1
    assert hist_data["total_pages"] == 0
    assert hist_data["has_next"] is False
    assert hist_data["has_prev"] is False


def test_partner_to_staff_transfer_appears_as_positive_credit(client: TestClient, db: Session, seed_data):
    """Partner -> Staff transfer appears as positive credit with partner info and reference."""
    partner = seed_data["partner_1"]
    staff_a = seed_data["staff_a"]

    transfer = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff_a.id,
        amount=150,
        idempotency_key="tx-idem-staff-test-001",
        remarks="Partner loyalty reward",
        created_at=datetime.now(timezone.utc),
    )
    db.add(transfer)
    db.commit()

    res = client.get("/api/v1/staff/points-history", headers=auth_headers(staff_a))
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1

    item = data["items"][0]
    assert item["id"] == f"tr-{transfer.id}"
    assert item["transaction_type"] == "transfer_received"
    assert item["direction"] == "credit"
    assert item["points"] == 150
    assert item["amount"] == 150
    assert item["reference_id"] == "tx-idem-staff-test-001"
    assert item["sender_name"] == "Apex Motors Workshop"
    assert "Apex Motors Workshop" in item["title"]
    assert item["created_at"] is not None


def test_staff_user_isolation(client: TestClient, db: Session, seed_data):
    """Staff A cannot see transfers intended for Staff B."""
    partner = seed_data["partner_1"]
    staff_a = seed_data["staff_a"]
    staff_b = seed_data["staff_b"]

    transfer_a = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff_a.id,
        amount=100,
        idempotency_key="tx-staff-a",
        created_at=datetime.now(timezone.utc),
    )
    transfer_b = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff_b.id,
        amount=250,
        idempotency_key="tx-staff-b",
        created_at=datetime.now(timezone.utc),
    )
    db.add_all([transfer_a, transfer_b])
    db.commit()

    # Staff A history
    res_a = client.get("/api/v1/staff/points-history", headers=auth_headers(staff_a))
    assert res_a.status_code == 200
    data_a = res_a.json()
    assert data_a["total"] == 1
    assert data_a["items"][0]["amount"] == 100
    assert data_a["items"][0]["reference_id"] == "tx-staff-a"

    # Staff B history
    res_b = client.get("/api/v1/staff/points-history", headers=auth_headers(staff_b))
    assert res_b.status_code == 200
    data_b = res_b.json()
    assert data_b["total"] == 1
    assert data_b["items"][0]["amount"] == 250
    assert data_b["items"][0]["reference_id"] == "tx-staff-b"


def test_pagination_and_deterministic_ordering(client: TestClient, db: Session, seed_data):
    """Staff points history supports pagination and deterministic newest-first ordering."""
    partner = seed_data["partner_1"]
    staff_a = seed_data["staff_a"]
    now = datetime.now(timezone.utc)

    # Insert 5 transfers at distinct timestamps
    transfers = []
    for i in range(1, 6):
        t = PointTransfer(
            sender_id=partner.id,
            recipient_id=staff_a.id,
            amount=i * 10,
            idempotency_key=f"tx-page-{i}",
            created_at=now - timedelta(minutes=50 - i * 10),  # i=5 is newest, i=1 is oldest
        )
        transfers.append(t)
    db.add_all(transfers)
    db.commit()

    headers = auth_headers(staff_a)

    # Page 1 with page_size=2
    res1 = client.get("/api/v1/staff/points-history?page=1&page_size=2", headers=headers)
    assert res1.status_code == 200
    d1 = res1.json()
    assert d1["total"] == 5
    assert d1["page"] == 1
    assert d1["page_size"] == 2
    assert d1["total_pages"] == 3
    assert d1["has_next"] is True
    assert d1["has_prev"] is False
    assert len(d1["items"]) == 2
    # Newest first: i=5 (50 pts), then i=4 (40 pts)
    assert d1["items"][0]["amount"] == 50
    assert d1["items"][1]["amount"] == 40

    # Page 2
    res2 = client.get("/api/v1/staff/points-history?page=2&page_size=2", headers=headers)
    assert res2.status_code == 200
    d2 = res2.json()
    assert d2["page"] == 2
    assert d2["has_next"] is True
    assert d2["has_prev"] is True
    assert len(d2["items"]) == 2
    assert d2["items"][0]["amount"] == 30
    assert d2["items"][1]["amount"] == 20

    # Page 3
    res3 = client.get("/api/v1/staff/points-history?page=3&page_size=2", headers=headers)
    assert res3.status_code == 200
    d3 = res3.json()
    assert d3["page"] == 3
    assert d3["has_next"] is False
    assert d3["has_prev"] is True
    assert len(d3["items"]) == 1
    assert d3["items"][0]["amount"] == 10


def test_balance_equals_sum_of_staff_history(client: TestClient, db: Session, seed_data):
    """Staff balance directly equals the sum of received transfers (positive history credits)."""
    partner_1 = seed_data["partner_1"]
    partner_2 = seed_data["partner_2"]
    staff_a = seed_data["staff_a"]

    db.add_all([
        PointTransfer(
            sender_id=partner_1.id,
            recipient_id=staff_a.id,
            amount=75,
            idempotency_key="tx-sum-1",
            created_at=datetime.now(timezone.utc),
        ),
        PointTransfer(
            sender_id=partner_2.id,
            recipient_id=staff_a.id,
            amount=125,
            idempotency_key="tx-sum-2",
            created_at=datetime.now(timezone.utc),
        ),
    ])
    db.commit()

    headers = auth_headers(staff_a)

    # 1. Check history
    res_hist = client.get("/api/v1/staff/points-history", headers=headers)
    assert res_hist.status_code == 200
    hist = res_hist.json()
    sum_history = sum(item["points"] for item in hist["items"])
    assert sum_history == 200

    # 2. Check balance
    res_bal = client.get("/api/v1/staff/balance", headers=headers)
    assert res_bal.status_code == 200
    bal = res_bal.json()
    assert bal["points_earned"] == 200
    assert bal["points_spent"] == 0
    assert bal["current_balance"] == 200
    assert bal["current_balance"] == sum_history


def test_existing_partner_and_customer_history_unchanged(client: TestClient, db: Session, seed_data):
    """Adding staff points history does not alter partner or customer points history."""
    partner = seed_data["partner_1"]
    staff_a = seed_data["staff_a"]
    customer = seed_data["customer"]

    # Transfer from Partner to Staff
    transfer = PointTransfer(
        sender_id=partner.id,
        recipient_id=staff_a.id,
        amount=60,
        idempotency_key="tx-reg-1",
        created_at=datetime.now(timezone.utc),
    )
    db.add(transfer)
    db.commit()

    # Partner history shows debit
    res_part = client.get("/api/v1/partner/points-history", headers=auth_headers(partner))
    assert res_part.status_code == 200
    part_hist = res_part.json()
    assert part_hist["total"] == 1
    assert part_hist["items"][0]["direction"] == "debit"
    assert part_hist["items"][0]["points"] == -60

    # Customer history remains empty
    res_cust = client.get("/api/v1/customer/points-history", headers=auth_headers(customer))
    assert res_cust.status_code == 200
    assert res_cust.json()["total"] == 0
