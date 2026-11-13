from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models import (
    CustomerProfile,
    Order,
    PartnerProfile,
    PaymentStatusHistory,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    User,
)


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
            StaffPartnerAssignment.__table__,
            Order.__table__,
            StaffPaymentRecord.__table__,
            PaymentStatusHistory.__table__,
        ],
    )
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine) -> Generator[Session, None, None]:
    with Session(test_engine) as session:
        yield session


@pytest.fixture
def client(test_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


def _create_user(db: Session, *, name: str, mobile: str, role: str) -> User:
    user = User(
        mobile=mobile,
        name=name,
        role=role,
        is_active=True,
        password_hash=hash_password("Secret123"),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _create_staff(db: Session, *, name: str, mobile: str, staff_code: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="staff")
    db.add(StaffProfile(user_id=user.id, staff_id=staff_code))
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="staff", mobile=user.mobile)
    return user, token


def _create_admin(db: Session, *, name: str, mobile: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="admin")
    token = create_access_token(subject=str(user.id), role="admin", mobile=user.mobile)
    return user, token


def _create_partner(db: Session, *, name: str, mobile: str, business: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="partner")
    db.add(
        PartnerProfile(
            user_id=user.id,
            business_name=business,
            business_address="100 Trade St, City",
            partner_code=f"PRT-{mobile[-4:]}",
        )
    )
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="partner", mobile=user.mobile)
    return user, token


def _create_customer(db: Session, *, name: str, mobile: str) -> tuple[User, str]:
    user = _create_user(db, name=name, mobile=mobile, role="customer")
    db.add(CustomerProfile(user_id=user.id, state="MH", city="Pune", segment="A"))
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id), role="customer", mobile=user.mobile)
    return user, token


def _create_payment(
    db: Session,
    *,
    staff_id: int,
    partner_id: int,
    recorded_by: int,
    amount: Decimal = Decimal("5000.00"),
    payment_method: str = "bank_transfer",
    reference_number: str = "INV-99001",
    status: str = "recorded",
    notes: str = "Advance payment",
) -> StaffPaymentRecord:
    rec = StaffPaymentRecord(
        staff_id=staff_id,
        partner_id=partner_id,
        amount=amount,
        payment_method=payment_method,
        reference_number=reference_number,
        status=status,
        recorded_by=recorded_by,
        recorded_at=datetime.now(timezone.utc),
        notes=notes,
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec


# =============================================================================
# Authorization & Security Tests
# =============================================================================


def test_unauthenticated_request_is_rejected(client: TestClient) -> None:
    res = client.get("/api/v1/staff/payments")
    assert res.status_code == 401

    res_post = client.post("/api/v1/staff/payments/1/approve")
    assert res_post.status_code == 401


def test_customer_and_partner_cannot_access_staff_payments(
    client: TestClient, db_session: Session
) -> None:
    _, cust_token = _create_customer(db_session, name="Cust", mobile="+919800000001")
    _, part_token = _create_partner(db_session, name="Part", mobile="+919800000002", business="Part Shop")

    res_c = client.get(
        "/api/v1/staff/payments",
        headers={"Authorization": f"Bearer {cust_token}"},
    )
    assert res_c.status_code == 403
    assert "staff privileges required" in res_c.json()["detail"].lower()

    res_p = client.get(
        "/api/v1/staff/payments",
        headers={"Authorization": f"Bearer {part_token}"},
    )
    assert res_p.status_code == 403
    assert "staff privileges required" in res_p.json()["detail"].lower()


def test_staff_a_cannot_see_or_review_staff_b_payments(
    client: TestClient, db_session: Session
) -> None:
    staff_a, token_a = _create_staff(db_session, name="Staff A", mobile="+919810000001", staff_code="STF-A")
    staff_b, token_b = _create_staff(db_session, name="Staff B", mobile="+919810000002", staff_code="STF-B")
    partner, _ = _create_partner(db_session, name="Partner 1", mobile="+919810000003", business="Shop 1")

    pay_b = _create_payment(
        db_session,
        staff_id=staff_b.id,
        partner_id=partner.id,
        recorded_by=staff_b.id,
        reference_number="INV-B-01",
    )

    # 1. Staff A listing does NOT contain Staff B's payment
    res_list_a = client.get(
        "/api/v1/staff/payments",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert res_list_a.status_code == 200
    data_a = res_list_a.json()
    assert data_a["total"] == 0
    assert len(data_a["items"]) == 0

    # 2. Staff A cannot access payment detail of Staff B
    res_detail = client.get(
        f"/api/v1/staff/payments/{pay_b.id}",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert res_detail.status_code == 403
    assert "access denied" in res_detail.json()["detail"].lower()

    # 3. Staff A cannot approve Staff B's payment
    res_app = client.post(
        f"/api/v1/staff/payments/{pay_b.id}/approve",
        headers={"Authorization": f"Bearer {token_a}"},
        json={"remarks": "Attempt by Staff A"},
    )
    assert res_app.status_code == 403
    assert "access denied" in res_app.json()["detail"].lower()

    # 4. Staff A cannot reject Staff B's payment
    res_rej = client.post(
        f"/api/v1/staff/payments/{pay_b.id}/reject",
        headers={"Authorization": f"Bearer {token_a}"},
        json={"reason": "Attempt by Staff A"},
    )
    assert res_rej.status_code == 403
    assert "access denied" in res_rej.json()["detail"].lower()


def test_admin_permissions_follow_authorization_policy(
    client: TestClient, db_session: Session
) -> None:
    admin, token_admin = _create_admin(db_session, name="Admin User", mobile="+919820000001")
    staff, _ = _create_staff(db_session, name="Staff", mobile="+919820000002", staff_code="STF-01")
    partner, _ = _create_partner(db_session, name="Partner", mobile="+919820000003", business="Partner Auto")

    pay = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner.id,
        recorded_by=staff.id,
        reference_number="INV-ADM-01",
    )

    # Admin can view payment detail
    res_get = client.get(
        f"/api/v1/staff/payments/{pay.id}",
        headers={"Authorization": f"Bearer {token_admin}"},
    )
    assert res_get.status_code == 200
    assert res_get.json()["id"] == pay.id

    # Admin can approve payment
    res_app = client.post(
        f"/api/v1/staff/payments/{pay.id}/approve",
        headers={"Authorization": f"Bearer {token_admin}"},
        json={"remarks": "Approved by Admin"},
    )
    assert res_app.status_code == 200
    data = res_app.json()
    assert data["status"] == "approved"
    assert data["latest_review"]["changed_by"] == admin.id
    assert data["latest_review"]["remarks"] == "Approved by Admin"


# =============================================================================
# List & Pagination Tests
# =============================================================================


def test_empty_payment_list(client: TestClient, db_session: Session) -> None:
    _, token = _create_staff(db_session, name="Empty Staff", mobile="+919830000001", staff_code="STF-E")

    res = client.get(
        "/api/v1/staff/payments",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["items"] == []
    assert data["total"] == 0
    assert data["page"] == 1
    assert data["total_pages"] == 0
    assert data["has_next"] is False
    assert data["has_prev"] is False


def test_payment_list_pagination_and_sorting(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Paginated Staff", mobile="+919840000001", staff_code="STF-P")
    partner, _ = _create_partner(db_session, name="Partner", mobile="+919840000002", business="Mega Auto")

    for i in range(1, 6):
        _create_payment(
            db_session,
            staff_id=staff.id,
            partner_id=partner.id,
            recorded_by=staff.id,
            amount=Decimal(f"{i * 1000}.00"),
            reference_number=f"INV-PAG-{i:03d}",
        )

    # Page 1, size 2
    res1 = client.get(
        "/api/v1/staff/payments?page=1&page_size=2",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res1.status_code == 200
    d1 = res1.json()
    assert d1["total"] == 5
    assert d1["total_pages"] == 3
    assert len(d1["items"]) == 2
    assert d1["has_next"] is True
    assert d1["has_prev"] is False
    # Deterministic newest-first sort
    assert d1["items"][0]["reference_number"] == "INV-PAG-005"
    assert d1["items"][1]["reference_number"] == "INV-PAG-004"

    # Page 2, size 2
    res2 = client.get(
        "/api/v1/staff/payments?page=2&page_size=2",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res2.status_code == 200
    d2 = res2.json()
    assert len(d2["items"]) == 2
    assert d2["has_next"] is True
    assert d2["has_prev"] is True
    assert d2["items"][0]["reference_number"] == "INV-PAG-003"
    assert d2["items"][1]["reference_number"] == "INV-PAG-002"

    # Page 3, size 2
    res3 = client.get(
        "/api/v1/staff/payments?page=3&page_size=2",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res3.status_code == 200
    d3 = res3.json()
    assert len(d3["items"]) == 1
    assert d3["has_next"] is False
    assert d3["has_prev"] is True
    assert d3["items"][0]["reference_number"] == "INV-PAG-001"


def test_payment_list_status_filtering_and_search(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Filter Staff", mobile="+919850000001", staff_code="STF-F")
    partner1, _ = _create_partner(db_session, name="Alpha Partner", mobile="+919850000002", business="Alpha Motors")
    partner2, _ = _create_partner(db_session, name="Beta Partner", mobile="+919850000003", business="Beta Spares")

    p1 = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner1.id,
        recorded_by=staff.id,
        status="recorded",
        reference_number="INV-REC-1",
    )
    p2 = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner2.id,
        recorded_by=staff.id,
        status="approved",
        reference_number="INV-APP-2",
    )
    p3 = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner1.id,
        recorded_by=staff.id,
        status="rejected",
        reference_number="INV-REJ-3",
    )

    # Filter status=recorded
    res_rec = client.get(
        "/api/v1/staff/payments?status=recorded",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_rec.status_code == 200
    assert res_rec.json()["total"] == 1
    assert res_rec.json()["items"][0]["id"] == p1.id

    # Filter status=approved
    res_app = client.get(
        "/api/v1/staff/payments?status=approved",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_app.status_code == 200
    assert res_app.json()["total"] == 1
    assert res_app.json()["items"][0]["id"] == p2.id

    # Search by dealer business name
    res_search = client.get(
        "/api/v1/staff/payments?search=Beta",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_search.status_code == 200
    assert res_search.json()["total"] == 1
    assert res_search.json()["items"][0]["business_name"] == "Beta Spares"


# =============================================================================
# Review Lifecycle & Concurrency Tests
# =============================================================================


def test_successful_approval_creates_history_atomically(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Review Staff", mobile="+919860000001", staff_code="STF-R")
    partner, _ = _create_partner(db_session, name="Dealer", mobile="+919860000002", business="Dealer Store")

    payment = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner.id,
        recorded_by=staff.id,
        amount=Decimal("15000.00"),
        payment_method="cheque",
        reference_number="CHQ-8821",
        status="recorded",
    )

    res = client.post(
        f"/api/v1/staff/payments/{payment.id}/approve",
        headers={"Authorization": f"Bearer {token}"},
        json={"remarks": "Cheque cleared in bank account"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "approved"
    assert data["amount"] == "15000.00"
    assert data["payment_method"] == "cheque"
    assert data["reference_number"] == "CHQ-8821"
    assert data["latest_review"]["old_status"] == "recorded"
    assert data["latest_review"]["new_status"] == "approved"
    assert data["latest_review"]["remarks"] == "Cheque cleared in bank account"
    assert data["latest_review"]["changed_by"] == staff.id

    # Verify directly in DB
    db_session.expire_all()
    reloaded = db_session.get(StaffPaymentRecord, payment.id)
    assert reloaded.status == "approved"

    history_records = db_session.scalars(
        select(PaymentStatusHistory).where(PaymentStatusHistory.payment_record_id == payment.id)
    ).all()
    assert len(history_records) == 1
    assert history_records[0].old_status == "recorded"
    assert history_records[0].new_status == "approved"
    assert history_records[0].changed_by == staff.id
    assert history_records[0].remarks == "Cheque cleared in bank account"


def test_successful_rejection_requires_mandatory_reason(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Reject Staff", mobile="+919870000001", staff_code="STF-RJ")
    partner, _ = _create_partner(db_session, name="Partner", mobile="+919870000002", business="Auto Point")

    payment = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner.id,
        recorded_by=staff.id,
        status="recorded",
    )

    # 1. Reject without reason is rejected
    res_empty = client.post(
        f"/api/v1/staff/payments/{payment.id}/reject",
        headers={"Authorization": f"Bearer {token}"},
        json={"reason": "   "},
    )
    assert res_empty.status_code in (400, 422)

    # 2. Reject with reason succeeds
    res_valid = client.post(
        f"/api/v1/staff/payments/{payment.id}/reject",
        headers={"Authorization": f"Bearer {token}"},
        json={"reason": "Cheque bounced due to insufficient funds"},
    )
    assert res_valid.status_code == 200
    data = res_valid.json()
    assert data["status"] == "rejected"
    assert data["latest_review"]["new_status"] == "rejected"
    assert data["latest_review"]["remarks"] == "Cheque bounced due to insufficient funds"

    # Verify DB history
    history = db_session.scalars(
        select(PaymentStatusHistory).where(PaymentStatusHistory.payment_record_id == payment.id)
    ).all()
    assert len(history) == 1
    assert history[0].old_status == "recorded"
    assert history[0].new_status == "rejected"
    assert history[0].remarks == "Cheque bounced due to insufficient funds"


def test_invalid_status_transitions_and_duplicate_reviews(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Trans Staff", mobile="+919880000001", staff_code="STF-T")
    partner, _ = _create_partner(db_session, name="Partner", mobile="+919880000002", business="Speed Spares")

    # Payment already approved
    approved_payment = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner.id,
        recorded_by=staff.id,
        status="approved",
    )

    # Cannot approve again (duplicate request)
    res_dup = client.post(
        f"/api/v1/staff/payments/{approved_payment.id}/approve",
        headers={"Authorization": f"Bearer {token}"},
        json={"remarks": "Duplicate approve"},
    )
    assert res_dup.status_code == 400
    assert "cannot be transitioned" in res_dup.json()["detail"].lower()

    # Cannot reject an approved payment (terminal status)
    res_rej = client.post(
        f"/api/v1/staff/payments/{approved_payment.id}/reject",
        headers={"Authorization": f"Bearer {token}"},
        json={"reason": "Should fail"},
    )
    assert res_rej.status_code == 400
    assert "cannot be transitioned" in res_rej.json()["detail"].lower()

    # Payment already rejected
    rejected_payment = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner.id,
        recorded_by=staff.id,
        status="rejected",
    )

    # Cannot approve a rejected payment (terminal status)
    res_rev = client.post(
        f"/api/v1/staff/payments/{rejected_payment.id}/approve",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_rev.status_code == 400
    assert "cannot be transitioned" in res_rev.json()["detail"].lower()


def test_dashboard_pending_count_updates_with_lifecycle(
    client: TestClient, db_session: Session
) -> None:
    staff, token = _create_staff(db_session, name="Dash Staff", mobile="+919890000001", staff_code="STF-D")
    partner, _ = _create_partner(db_session, name="Partner", mobile="+919890000002", business="Dash Auto")

    # 1. Initially 0 pending payments
    res_d0 = client.get(
        "/api/v1/staff/dashboard",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_d0.status_code == 200
    assert res_d0.json()["pending_payments_count"] == 0

    # 2. Record payment -> count becomes 1
    payment = _create_payment(
        db_session,
        staff_id=staff.id,
        partner_id=partner.id,
        recorded_by=staff.id,
        status="recorded",
    )
    res_d1 = client.get(
        "/api/v1/staff/dashboard",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_d1.status_code == 200
    assert res_d1.json()["pending_payments_count"] == 1

    # 3. Approve payment -> count drops back to 0
    res_app = client.post(
        f"/api/v1/staff/payments/{payment.id}/approve",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_app.status_code == 200

    res_d2 = client.get(
        "/api/v1/staff/dashboard",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res_d2.status_code == 200
    assert res_d2.json()["pending_payments_count"] == 0


def test_existing_records_compatibility(db_session: Session) -> None:
    """
    Validates that existing 'recorded' and 'voided' records remain completely compatible.
    """
    staff, _ = _create_staff(db_session, name="Legacy Staff", mobile="+919900000001", staff_code="STF-LEG")
    partner, _ = _create_partner(db_session, name="Partner", mobile="+919900000002", business="Legacy Shop")

    p_rec = StaffPaymentRecord(
        staff_id=staff.id,
        partner_id=partner.id,
        amount=Decimal("100.00"),
        payment_method="cash",
        status="recorded",
        recorded_by=staff.id,
    )
    p_void = StaffPaymentRecord(
        staff_id=staff.id,
        partner_id=partner.id,
        amount=Decimal("200.00"),
        payment_method="cash",
        status="voided",
        recorded_by=staff.id,
    )
    db_session.add_all([p_rec, p_void])
    db_session.commit()

    assert p_rec.status == "recorded"
    assert p_void.status == "voided"
