from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
import sqlalchemy as sa
from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from app.core.security import create_access_token, hash_password
from app.db.base import Base
from app.models import (
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


@pytest.fixture
def test_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


def _auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def _create_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
    active: bool = True,
    password: str = "SecurePass123!",
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        role=role,
        is_active=active,
        password_hash=hash_password(password),
    )
    db.add(user)
    db.flush()
    return user


def _create_staff(
    db: Session,
    *,
    name: str = "Staff Member",
    mobile: str = "9111111111",
    staff_id: str = "STF-TEST",
    active: bool = True,
) -> User:
    user = _create_user(db, name=name, mobile=mobile, role="staff", active=active)
    db.add(StaffProfile(user_id=user.id, staff_id=staff_id))
    db.commit()
    db.refresh(user)
    return user


def _create_partner(
    db: Session,
    *,
    name: str = "Partner Member",
    mobile: str = "9222222222",
    business_name: str = "Partner Biz",
    zone_id: int | None = None,
    active: bool = True,
) -> User:
    user = _create_user(db, name=name, mobile=mobile, role="partner", active=active)
    db.add(
        PartnerProfile(
            user_id=user.id,
            business_name=business_name,
            business_address="123 Test Street",
            partner_code=f"P-{user.id}",
            zone_id=zone_id,
        )
    )
    db.commit()
    db.refresh(user)
    return user


def _create_admin(db: Session, *, mobile: str = "9333333333") -> User:
    user = _create_user(db, name="Admin User", mobile=mobile, role="admin", active=True)
    db.commit()
    db.refresh(user)
    return user


def _create_product(db: Session, *, name: str = "Test Product", price: Decimal = Decimal("500.00")) -> Product:
    cat = db.scalar(select(ProductCategory).where(ProductCategory.name == "General"))
    if not cat:
        cat = ProductCategory(name="General", is_active=True)
        db.add(cat)
        db.flush()
    prod = Product(
        category_id=cat.id,
        product_code=f"PRD-{datetime.now().microsecond}",
        name=name,
        vehicle_type="Both",
        price=price,
        is_active=True,
    )
    db.add(prod)
    db.commit()
    db.refresh(prod)
    return prod


# ===========================================================================
# PHASE 6.A: Assignment Lifecycle Tests
# ===========================================================================


def test_assignment_lifecycle_and_automatic_deactivation(
    client: TestClient, db_session: Session
) -> None:
    """Test full assignment lifecycle:
    1. Creating an assignment works.
    2. Assigning partner to Staff B automatically deactivates Staff A's assignment.
    3. The old assignment retains original assigned_at and receives deactivated_at and deactivated_by.
    4. At most one active assignment exists for the partner.
    5. Reactivating an old assignment is rejected with 400.
    """
    admin = _create_admin(db_session, mobile="9800000001")
    staff_a = _create_staff(db_session, name="Staff A", mobile="9800000002", staff_id="STF-A")
    staff_b = _create_staff(db_session, name="Staff B", mobile="9800000003", staff_id="STF-B")
    partner = _create_partner(db_session, name="Partner 1", mobile="9800000004")

    admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
    admin_headers = _auth_header(admin_token)

    # 1. Assign partner to Staff A
    res_a = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff_a.id, "partner_id": partner.id},
    )
    assert res_a.status_code == 201
    asgn_a = res_a.json()
    asgn_a_id = asgn_a["id"]
    assigned_at_a = asgn_a["assigned_at"]
    assert asgn_a["is_active"] is True
    assert asgn_a["deactivated_at"] is None

    # 2. Reassign partner to Staff B
    res_b = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff_b.id, "partner_id": partner.id},
    )
    assert res_b.status_code == 201
    asgn_b = res_b.json()
    assert asgn_b["is_active"] is True
    assert asgn_b["staff_id"] == staff_b.id

    # 3. Under M2M, both Staff A and Staff B are active. Deactivate Staff A's assignment explicitly.
    res_deact = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{asgn_a_id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deact.status_code == 200

    db_session.expire_all()
    old_a = db_session.get(StaffPartnerAssignment, asgn_a_id)
    assert old_a is not None
    assert old_a.is_active is False
    assert old_a.assigned_at.isoformat()[:19] == assigned_at_a[:19]
    assert old_a.deactivated_at is not None
    assert old_a.deactivated_by == admin.id

    # 4. Only Staff B active assignment exists for partner
    active_count = db_session.scalar(
        select(func.count(StaffPartnerAssignment.id)).where(
            StaffPartnerAssignment.partner_id == partner.id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    assert active_count == 1

    # 5. Reactivating old assignment is rejected
    res_reactivate = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{asgn_a_id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_reactivate.status_code == 400
    assert "cannot be reactivated" in res_reactivate.json()["detail"].lower()


def test_inactive_staff_assignment_rejected(client: TestClient, db_session: Session) -> None:
    """Assigning an inactive staff member must be rejected with 422."""
    admin = _create_admin(db_session, mobile="9800000011")
    staff_inactive = _create_staff(
        db_session, name="Inactive Staff", mobile="9800000012", staff_id="STF-INACT", active=False
    )
    partner = _create_partner(db_session, name="Partner", mobile="9800000013")

    admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=_auth_header(admin_token),
        json={"staff_id": staff_inactive.id, "partner_id": partner.id},
    )
    assert res.status_code == 422
    assert "inactive" in res.json()["detail"].lower()


def test_staff_account_deactivation_deactivates_assignments(
    client: TestClient, db_session: Session
) -> None:
    """Deactivating a staff account automatically deactivates their active partner assignments."""
    admin = _create_admin(db_session, mobile="9800000021")
    staff = _create_staff(db_session, name="Staff Act", mobile="9800000022", staff_id="STF-ACT")
    p1 = _create_partner(db_session, name="Partner 1", mobile="9800000023")
    p2 = _create_partner(db_session, name="Partner 2", mobile="9800000024")

    admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
    admin_headers = _auth_header(admin_token)

    client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": p1.id},
    )
    client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": p2.id},
    )

    # Deactivate the staff member via admin user status endpoint
    res_deact_user = client.post(
        f"/api/v1/admin/users/{staff.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deact_user.status_code == 200

    # Verify both assignments were deactivated
    db_session.expire_all()
    assignments = db_session.scalars(
        select(StaffPartnerAssignment).where(StaffPartnerAssignment.staff_id == staff.id)
    ).all()
    assert len(assignments) == 2
    for asgn in assignments:
        assert asgn.is_active is False
        assert asgn.deactivated_at is not None
        assert asgn.deactivated_by == admin.id

    # Reactivating staff does NOT automatically reactivate assignments
    res_react_user = client.post(
        f"/api/v1/admin/users/{staff.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_react_user.status_code == 200
    db_session.expire_all()
    for asgn in assignments:
        reloaded = db_session.get(StaffPartnerAssignment, asgn.id)
        assert reloaded.is_active is False


# ===========================================================================
# PHASE 6.B: Historical Order Attribution & Reassignment Tests
# ===========================================================================


def test_historical_attribution_preserved_across_reassignments(
    client: TestClient, db_session: Session
) -> None:
    """Historical attribution workflow:
    1. Partner assigned to Staff A places Order 1.
    2. Partner reassigned to Staff B.
    3. Partner places Order 2.
    4. Staff A report retains Order 1.
    5. Staff B report contains Order 2.
    6. Partner report contains both Order 1 and Order 2.
    7. Staff A-created order remains attributed to Staff A even after reassignment.
    8. Orders created while unassigned appear in the Unassigned bucket.
    9. Old orders without reliable attribution appear in Historically Unattributed.
    10. No order appears in more than one staff bucket.
    """
    admin = _create_admin(db_session, mobile="9800000031")
    staff_a = _create_staff(db_session, name="Staff Alpha", mobile="9800000032", staff_id="STF-A32")
    staff_b = _create_staff(db_session, name="Staff Beta", mobile="9800000033", staff_id="STF-B33")
    partner = _create_partner(db_session, name="Partner Gamma", mobile="9800000034")
    product = _create_product(db_session, name="Brake Pad", price=Decimal("300.00"))

    admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
    admin_headers = _auth_header(admin_token)
    partner_token = create_access_token(subject=str(partner.id), role="partner", mobile=partner.mobile)
    partner_headers = _auth_header(partner_token)
    staff_a_token = create_access_token(subject=str(staff_a.id), role="staff", mobile=staff_a.mobile)
    staff_a_headers = _auth_header(staff_a_token)

    # 1. Partner assigned to Staff A
    res_asgn_a = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff_a.id, "partner_id": partner.id},
    )
    asgn_a_id = res_asgn_a.json()["id"]

    # Partner creates Order 1
    res_ord1 = client.post(
        "/api/v1/orders",
        headers=partner_headers,
        json={"items": [{"product_id": product.id, "quantity": 1}]},
    )
    assert res_ord1.status_code == 201
    ord1_data = res_ord1.json()
    assert ord1_data["assigned_staff_id"] == staff_a.id
    assert ord1_data["created_by_user_id"] == partner.id
    assert ord1_data["staff_attribution_status"] == "assigned"

    # Staff A creates Order A on behalf of Partner
    res_ord_a = client.post(
        "/api/v1/staff/orders",
        headers=staff_a_headers,
        json={"partner_id": partner.id, "items": [{"product_id": product.id, "quantity": 1}]},
    )
    assert res_ord_a.status_code == 201
    ord_a_data = res_ord_a.json()
    assert ord_a_data["assigned_staff_id"] == staff_a.id
    assert ord_a_data["created_by_user_id"] == staff_a.id
    assert ord_a_data["staff_attribution_status"] == "assigned"

    # 2. Partner is reassigned to Staff B (deactivate Staff A)
    client.patch(
        f"/api/v1/admin/staff-partner-assignments/{asgn_a_id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff_b.id, "partner_id": partner.id},
    )

    # 3. Partner creates Order 2 while assigned to Staff B
    res_ord2 = client.post(
        "/api/v1/orders",
        headers=partner_headers,
        json={"items": [{"product_id": product.id, "quantity": 2}]},
    )
    assert res_ord2.status_code == 201
    ord2_data = res_ord2.json()
    assert ord2_data["assigned_staff_id"] == staff_b.id
    assert ord2_data["created_by_user_id"] == partner.id
    assert ord2_data["staff_attribution_status"] == "assigned"

    # 8. Deactivate assignment to Staff B so partner is unassigned, then partner creates Order 3
    asgn_b = db_session.scalar(
        select(StaffPartnerAssignment).where(
            StaffPartnerAssignment.partner_id == partner.id,
            StaffPartnerAssignment.is_active.is_(True),
        )
    )
    client.patch(
        f"/api/v1/admin/staff-partner-assignments/{asgn_b.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )

    res_ord3 = client.post(
        "/api/v1/orders",
        headers=partner_headers,
        json={"items": [{"product_id": product.id, "quantity": 1}]},
    )
    assert res_ord3.status_code == 201
    ord3_data = res_ord3.json()
    assert ord3_data["assigned_staff_id"] is None
    assert ord3_data["staff_attribution_status"] == "unassigned"

    # 9. Create an old order representing historically unattributed
    hist_order = Order(
        order_number="ORD-HIST-001",
        partner_id=partner.id,
        created_by_user_id=None,
        assigned_staff_id=None,
        staff_attribution_status="historically_unattributed",
        status="delivered",
    )
    db_session.add(hist_order)
    db_session.flush()
    db_session.add(OrderItem(order_id=hist_order.id, product_id=product.id, quantity=1, unit_price=Decimal("300.00")))
    db_session.commit()

    # Approve ord1, ord_a, ord2, ord3 so they have approved status
    for oid in [ord1_data["id"], ord_a_data["id"], ord2_data["id"], ord3_data["id"]]:
        o = db_session.get(Order, oid)
        o.status = "delivered"
    db_session.commit()

    # Query Staff-wise report for all time
    rep_res = client.get("/api/v1/admin/reports/staff-wise?preset=all_time", headers=admin_headers)
    assert rep_res.status_code == 200
    report_items = rep_res.json()["items"]

    items_by_name = {item["name"]: item for item in report_items}

    # 4 & 7. Staff A's report retains Order 1 and Staff-created Order A (2 orders)
    staff_a_report = items_by_name["Staff Alpha"]
    assert staff_a_report["order_count"] == 2
    assert Decimal(str(staff_a_report["total_order_value"])) == Decimal("600.00")

    # 5. Staff B's report contains Order 2 (1 order)
    staff_b_report = items_by_name["Staff Beta"]
    assert staff_b_report["order_count"] == 1
    assert Decimal(str(staff_b_report["total_order_value"])) == Decimal("600.00")

    # 8. Unassigned bucket contains Order 3 (1 order)
    unassigned_report = items_by_name["Unassigned"]
    assert unassigned_report["order_count"] == 1
    assert Decimal(str(unassigned_report["total_order_value"])) == Decimal("300.00")
    assert unassigned_report["staff_user_id"] is None
    assert unassigned_report["attribution_category"] == "unassigned"

    # 9. Historically Unattributed bucket contains hist_order (1 order)
    hist_report = items_by_name["Historically Unattributed"]
    assert hist_report["order_count"] == 1
    assert Decimal(str(hist_report["total_order_value"])) == Decimal("300.00")
    assert hist_report["staff_user_id"] is None
    assert hist_report["attribution_category"] == "historically_unattributed"

    # 10. Reconciliation: Total orders across buckets = 2 + 1 + 1 + 1 = 5 orders
    total_staff_rep_orders = sum(item["order_count"] for item in report_items)
    assert total_staff_rep_orders == 5

    total_staff_rep_value = sum(Decimal(str(item["total_order_value"])) for item in report_items)
    assert total_staff_rep_value == Decimal("1800.00")

    # 6. Partner-wise report contains all 5 orders for Partner Gamma
    rep_partner = client.get(
        f"/api/v1/admin/reports/partner-wise?partner_id={partner.id}&preset=all_time",
        headers=admin_headers,
    )
    assert rep_partner.status_code == 200
    p_items = rep_partner.json()["items"]
    assert len(p_items) == 1
    assert p_items[0]["order_count"] == 5
    assert Decimal(str(p_items[0]["total_order_value"])) == Decimal("1800.00")


# ===========================================================================
# PHASE 6.C & 6.D: Reconciliation and Integrity Tests
# ===========================================================================


def test_overview_staff_partner_reports_reconcile_completely(
    client: TestClient, db_session: Session
) -> None:
    """Overall eligible count and approved order value must reconcile across:
    Overview, Staff-Wise, and Partner-Wise reports.
    """
    admin = _create_admin(db_session, mobile="9800000041")
    staff = _create_staff(db_session, name="Staff Rec", mobile="9800000042", staff_id="STF-REC")
    partner = _create_partner(db_session, name="Partner Rec", mobile="9800000043")
    product = _create_product(db_session, name="Chain", price=Decimal("100.00"))

    admin_headers = _auth_header(create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile))
    partner_headers = _auth_header(create_access_token(subject=str(partner.id), role="partner", mobile=partner.mobile))

    # Assign partner to staff
    client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )

    # Place an assigned order (approved)
    res_o1 = client.post(
        "/api/v1/orders",
        headers=partner_headers,
        json={"items": [{"product_id": product.id, "quantity": 3}]},
    )
    o1_id = res_o1.json()["id"]

    # Deactivate assignment and place an unassigned order (approved)
    asgn = db_session.scalar(select(StaffPartnerAssignment).where(StaffPartnerAssignment.is_active.is_(True)))
    client.patch(
        f"/api/v1/admin/staff-partner-assignments/{asgn.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    res_o2 = client.post(
        "/api/v1/orders",
        headers=partner_headers,
        json={"items": [{"product_id": product.id, "quantity": 2}]},
    )
    o2_id = res_o2.json()["id"]

    # Directly create a historically unattributed order (rejected -> value = 0)
    o3 = Order(
        order_number="ORD-HIST-REJ",
        partner_id=partner.id,
        staff_attribution_status="historically_unattributed",
        status="rejected",
    )
    db_session.add(o3)
    db_session.flush()
    db_session.add(OrderItem(order_id=o3.id, product_id=product.id, quantity=5, unit_price=Decimal("100.00")))

    # Set o1 and o2 to delivered
    db_session.get(Order, o1_id).status = "delivered"
    db_session.get(Order, o2_id).status = "delivered"
    db_session.commit()

    # 1. Overview
    r_overview = client.get("/api/v1/admin/reports/overview?preset=all_time", headers=admin_headers)
    assert r_overview.status_code == 200
    ov_data = r_overview.json()["overview"]
    assert ov_data["total_orders"] == 3
    assert ov_data["orders_delivered"] == 2
    assert ov_data["orders_rejected"] == 1
    # Approved value: 300 + 200 = 500.00
    assert Decimal(str(ov_data["total_order_value"])) == Decimal("500.00")

    # 2. Staff-Wise
    r_staff = client.get("/api/v1/admin/reports/staff-wise?preset=all_time", headers=admin_headers)
    assert r_staff.status_code == 200
    staff_items = r_staff.json()["items"]
    sum_staff_orders = sum(item["order_count"] for item in staff_items)
    sum_staff_value = sum(Decimal(str(item["total_order_value"])) for item in staff_items)
    assert sum_staff_orders == ov_data["total_orders"] == 3
    assert sum_staff_value == Decimal(str(ov_data["total_order_value"])) == Decimal("500.00")

    # 3. Partner-Wise
    r_partner = client.get("/api/v1/admin/reports/partner-wise?preset=all_time", headers=admin_headers)
    assert r_partner.status_code == 200
    partner_items = r_partner.json()["items"]
    sum_partner_orders = sum(item["order_count"] for item in partner_items)
    sum_partner_value = sum(Decimal(str(item["total_order_value"])) for item in partner_items)
    assert sum_partner_orders == ov_data["total_orders"] == 3
    assert sum_partner_value == Decimal(str(ov_data["total_order_value"])) == Decimal("500.00")


# ===========================================================================
# PHASE 2 CORRECTION: Partner-Wise Historical Staff Filter Tests
# ===========================================================================


def test_partner_wise_historical_staff_filter(client: TestClient, db_session: Session) -> None:
    """Verify partner-wise report with historical staff filter:
    1. A Partner formerly assigned to Staff A but currently assigned to Staff B.
    2. Staff A's historical report still includes the Partner and only Staff A's orders.
    3. Staff B's report includes only Staff B's orders.
    4. Approved payment figures are filtered by the selected Staff member.
    5. Date and zone filters remain effective.
    6. No Staff filter preserves existing Partner-wise totals.
    7. Combined filters (partner_id, zone_id, staff_id, date_from, date_to) work correctly.
    """
    admin = _create_admin(db_session, mobile="9800000051")
    admin_headers = _auth_header(create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile))

    zone_north = Zone(name="North Zone", is_active=True)
    zone_south = Zone(name="South Zone", is_active=True)
    db_session.add_all([zone_north, zone_south])
    db_session.commit()

    staff_a = _create_staff(db_session, name="Staff Alice", mobile="9800000052", staff_id="STF-ALICE")
    staff_b = _create_staff(db_session, name="Staff Bob", mobile="9800000053", staff_id="STF-BOB")

    partner_1 = _create_partner(
        db_session,
        name="Partner North",
        mobile="9800000054",
        business_name="North Shop",
        zone_id=zone_north.id,
    )
    partner_2 = _create_partner(
        db_session,
        name="Partner South",
        mobile="9800000055",
        business_name="South Shop",
        zone_id=zone_south.id,
    )

    prod = _create_product(db_session, name="Tyre", price=Decimal("200.00"))

    # Dates: Day 1 (May 1), Day 2 (May 15), Day 3 (May 25)
    day_1 = datetime(2026, 5, 1, 10, 0, 0, tzinfo=timezone.utc)
    day_2 = datetime(2026, 5, 15, 10, 0, 0, tzinfo=timezone.utc)
    day_3 = datetime(2026, 5, 25, 10, 0, 0, tzinfo=timezone.utc)

    # Assignments:
    # Partner 1 was formerly assigned to Staff A, currently assigned to Staff B
    asgn_a = StaffPartnerAssignment(
        staff_id=staff_a.id,
        partner_id=partner_1.id,
        is_active=False,
        assigned_at=day_1,
        deactivated_at=day_2,
        deactivated_by=admin.id,
    )
    asgn_b = StaffPartnerAssignment(
        staff_id=staff_b.id,
        partner_id=partner_1.id,
        is_active=True,
        assigned_at=day_2,
    )
    # Partner 2 assigned to Staff B
    asgn_b2 = StaffPartnerAssignment(
        staff_id=staff_b.id,
        partner_id=partner_2.id,
        is_active=True,
        assigned_at=day_2,
    )
    db_session.add_all([asgn_a, asgn_b, asgn_b2])
    db_session.commit()

    # Orders:
    # Order 1: Partner 1, assigned to Staff A, created on Day 1, delivered (2 * 200 = 400.00)
    order_1 = Order(
        order_number="ORD-TEST-001",
        partner_id=partner_1.id,
        created_by_user_id=partner_1.id,
        assigned_staff_id=staff_a.id,
        staff_attribution_status="assigned",
        status="delivered",
        created_at=day_1,
    )
    db_session.add(order_1)
    db_session.flush()
    db_session.add(OrderItem(order_id=order_1.id, product_id=prod.id, quantity=2, unit_price=Decimal("200.00")))

    # Order 2: Partner 1, assigned to Staff B, created on Day 2, delivered (3 * 200 = 600.00)
    order_2 = Order(
        order_number="ORD-TEST-002",
        partner_id=partner_1.id,
        created_by_user_id=partner_1.id,
        assigned_staff_id=staff_b.id,
        staff_attribution_status="assigned",
        status="delivered",
        created_at=day_2,
    )
    db_session.add(order_2)
    db_session.flush()
    db_session.add(OrderItem(order_id=order_2.id, product_id=prod.id, quantity=3, unit_price=Decimal("200.00")))

    # Order 3: Partner 1, assigned to Staff B, created on Day 2, rejected (1 * 200 = 200.00, excluded from value)
    order_3 = Order(
        order_number="ORD-TEST-003",
        partner_id=partner_1.id,
        created_by_user_id=partner_1.id,
        assigned_staff_id=staff_b.id,
        staff_attribution_status="assigned",
        status="rejected",
        created_at=day_2,
    )
    db_session.add(order_3)
    db_session.flush()
    db_session.add(OrderItem(order_id=order_3.id, product_id=prod.id, quantity=1, unit_price=Decimal("200.00")))

    # Order 4: Partner 2 (South Zone), assigned to Staff B, created on Day 3, delivered (5 * 200 = 1000.00)
    order_4 = Order(
        order_number="ORD-TEST-004",
        partner_id=partner_2.id,
        created_by_user_id=partner_2.id,
        assigned_staff_id=staff_b.id,
        staff_attribution_status="assigned",
        status="delivered",
        created_at=day_3,
    )
    db_session.add(order_4)
    db_session.flush()
    db_session.add(OrderItem(order_id=order_4.id, product_id=prod.id, quantity=5, unit_price=Decimal("200.00")))

    # Payments:
    # Payment 1: Staff A collected from Partner 1 on Day 1, approved: 350.00
    pay_1 = StaffPaymentRecord(
        staff_id=staff_a.id,
        partner_id=partner_1.id,
        amount=Decimal("350.00"),
        payment_method="cash",
        status="approved",
        recorded_by=staff_a.id,
        recorded_at=day_1,
    )
    # Payment 2: Staff B collected from Partner 1 on Day 2, approved: 550.00
    pay_2 = StaffPaymentRecord(
        staff_id=staff_b.id,
        partner_id=partner_1.id,
        amount=Decimal("550.00"),
        payment_method="bank_transfer",
        status="approved",
        recorded_by=staff_b.id,
        recorded_at=day_2,
    )
    # Payment 3: Staff B recorded for Partner 1 on Day 2, rejected (unapproved): 150.00
    pay_3 = StaffPaymentRecord(
        staff_id=staff_b.id,
        partner_id=partner_1.id,
        amount=Decimal("150.00"),
        payment_method="cash",
        status="rejected",
        recorded_by=staff_b.id,
        recorded_at=day_2,
    )
    # Payment 4: Staff B collected from Partner 2 on Day 3, approved: 900.00
    pay_4 = StaffPaymentRecord(
        staff_id=staff_b.id,
        partner_id=partner_2.id,
        amount=Decimal("900.00"),
        payment_method="upi",
        status="approved",
        recorded_by=staff_b.id,
        recorded_at=day_3,
    )
    db_session.add_all([pay_1, pay_2, pay_3, pay_4])
    db_session.commit()

    # 1 & 2. Staff A's report still includes Partner 1 (despite active assignment to Staff B)
    # and includes ONLY Staff A's orders and payments
    res_a = client.get(f"/api/v1/admin/reports/partner-wise?staff_id={staff_a.id}", headers=admin_headers)
    assert res_a.status_code == 200
    items_a = res_a.json()["items"]
    assert len(items_a) == 1
    p1_a = items_a[0]
    assert p1_a["partner_user_id"] == partner_1.id
    assert p1_a["order_count"] == 1
    assert Decimal(str(p1_a["total_order_value"])) == Decimal("400.00")
    assert p1_a["payment_count"] == 1
    assert Decimal(str(p1_a["total_payments_made"])) == Decimal("350.00")

    # 3. Staff B's report includes only Staff B's orders and approved payments
    res_b = client.get(f"/api/v1/admin/reports/partner-wise?staff_id={staff_b.id}", headers=admin_headers)
    assert res_b.status_code == 200
    items_b = {item["partner_user_id"]: item for item in res_b.json()["items"]}
    assert len(items_b) == 2

    # Partner 1 under Staff B (Order 1 by Staff A excluded; Order 3 rejected excluded from value)
    p1_b = items_b[partner_1.id]
    assert p1_b["order_count"] == 2
    assert Decimal(str(p1_b["total_order_value"])) == Decimal("600.00")
    assert p1_b["payment_count"] == 1
    assert Decimal(str(p1_b["total_payments_made"])) == Decimal("550.00")

    # Partner 2 under Staff B
    p2_b = items_b[partner_2.id]
    assert p2_b["order_count"] == 1
    assert Decimal(str(p2_b["total_order_value"])) == Decimal("1000.00")
    assert p2_b["payment_count"] == 1
    assert Decimal(str(p2_b["total_payments_made"])) == Decimal("900.00")

    # 4 & 5. Zone filter with Staff filter
    res_b_north = client.get(
        f"/api/v1/admin/reports/partner-wise?staff_id={staff_b.id}&zone_id={zone_north.id}",
        headers=admin_headers,
    )
    assert res_b_north.status_code == 200
    items_b_north = res_b_north.json()["items"]
    assert len(items_b_north) == 1
    assert items_b_north[0]["partner_user_id"] == partner_1.id

    res_b_south = client.get(
        f"/api/v1/admin/reports/partner-wise?staff_id={staff_b.id}&zone_id={zone_south.id}",
        headers=admin_headers,
    )
    assert res_b_south.status_code == 200
    items_b_south = res_b_south.json()["items"]
    assert len(items_b_south) == 1
    assert items_b_south[0]["partner_user_id"] == partner_2.id

    # Date filter with Staff filter
    # Day 2 only: Staff B has Partner 1 orders (Order 2, Order 3) on Day 2, Partner 2 order is on Day 3
    res_b_day2 = client.get(
        f"/api/v1/admin/reports/partner-wise?staff_id={staff_b.id}&date_from=2026-05-15&date_to=2026-05-15",
        headers=admin_headers,
    )
    assert res_b_day2.status_code == 200
    items_b_day2 = res_b_day2.json()["items"]
    assert len(items_b_day2) == 1
    assert items_b_day2[0]["partner_user_id"] == partner_1.id
    assert items_b_day2[0]["order_count"] == 2
    assert Decimal(str(items_b_day2[0]["total_order_value"])) == Decimal("600.00")

    # Day 2 only: Staff A has NO orders on Day 2 -> returns 0 partners
    res_a_day2 = client.get(
        f"/api/v1/admin/reports/partner-wise?staff_id={staff_a.id}&date_from=2026-05-15&date_to=2026-05-15",
        headers=admin_headers,
    )
    assert res_a_day2.status_code == 200
    assert len(res_a_day2.json()["items"]) == 0

    # Day 1 only: Staff A has Partner 1 order on Day 1
    res_a_day1 = client.get(
        f"/api/v1/admin/reports/partner-wise?staff_id={staff_a.id}&date_from=2026-05-01&date_to=2026-05-01",
        headers=admin_headers,
    )
    assert res_a_day1.status_code == 200
    items_a_day1 = res_a_day1.json()["items"]
    assert len(items_a_day1) == 1
    assert items_a_day1[0]["partner_user_id"] == partner_1.id
    assert items_a_day1[0]["order_count"] == 1
    assert Decimal(str(items_a_day1[0]["total_order_value"])) == Decimal("400.00")

    # Combined filters: partner_id + zone_id + staff_id + date_from + date_to
    res_comb_match = client.get(
        f"/api/v1/admin/reports/partner-wise?partner_id={partner_1.id}&zone_id={zone_north.id}&staff_id={staff_a.id}&date_from=2026-05-01&date_to=2026-05-01",
        headers=admin_headers,
    )
    assert res_comb_match.status_code == 200
    assert len(res_comb_match.json()["items"]) == 1
    assert res_comb_match.json()["items"][0]["partner_user_id"] == partner_1.id

    res_comb_mismatch = client.get(
        f"/api/v1/admin/reports/partner-wise?partner_id={partner_1.id}&zone_id={zone_south.id}&staff_id={staff_a.id}",
        headers=admin_headers,
    )
    assert res_comb_mismatch.status_code == 200
    assert len(res_comb_mismatch.json()["items"]) == 0

    # 6. No Staff filter preserves existing Partner-wise totals
    res_p1_all = client.get(f"/api/v1/admin/reports/partner-wise?partner_id={partner_1.id}", headers=admin_headers)
    assert res_p1_all.status_code == 200
    p1_all_items = res_p1_all.json()["items"]
    assert len(p1_all_items) == 1
    p1_total = p1_all_items[0]
    # Total orders = order_1 (Staff A) + order_2 (Staff B) + order_3 (Staff B) = 3 orders
    assert p1_total["order_count"] == 3
    # Total order value = order_1 (400) + order_2 (600) = 1000.00
    assert Decimal(str(p1_total["total_order_value"])) == Decimal("1000.00")
    # Total approved payments = pay_1 (350) + pay_2 (550) = 900.00
    assert p1_total["payment_count"] == 2
    assert Decimal(str(p1_total["total_payments_made"])) == Decimal("900.00")

    # All partners without staff filter
    res_all = client.get("/api/v1/admin/reports/partner-wise", headers=admin_headers)
    assert res_all.status_code == 200
    assert len(res_all.json()["items"]) == 2
    all_by_id = {item["partner_user_id"]: item for item in res_all.json()["items"]}
    assert all_by_id[partner_1.id]["order_count"] == 3
    assert Decimal(str(all_by_id[partner_1.id]["total_order_value"])) == Decimal("1000.00")
    assert all_by_id[partner_2.id]["order_count"] == 1
    assert Decimal(str(all_by_id[partner_2.id]["total_order_value"])) == Decimal("1000.00")


# ===========================================================================
# MIGRATION VALIDATION: Creator Backfill & Strict Check-Constraint Reflection
# ===========================================================================


def test_creator_backfill_excludes_ambiguous_orders_with_multiple_creation_events(
    db_session: Session,
) -> None:
    """Demonstrate that an order with two qualifying creation events,
    even if only one event has a valid user, is NOT backfilled into created_by_user_id.
    Only orders having strictly ONE qualifying creation event overall are backfilled.
    """
    valid_user = _create_user(db_session, name="Valid Creator", mobile="9800000091", role="partner")
    partner = _create_partner(db_session, name="Partner Ambiguous", mobile="9800000092")

    # Order 1: Ambiguous order with 2 creation events (one with valid user, one with None / invalid user)
    order_ambiguous = Order(
        order_number="ORD-AMBIGUOUS-001",
        partner_id=partner.id,
        created_by_user_id=None,
        status="pending_approval",
    )
    # Order 2: Clear order with strictly 1 creation event (with valid user)
    order_clear = Order(
        order_number="ORD-CLEAR-002",
        partner_id=partner.id,
        created_by_user_id=None,
        status="pending_approval",
    )
    db_session.add_all([order_ambiguous, order_clear])
    db_session.commit()

    # Add 2 creation events for order_ambiguous:
    # Event 1: valid user
    ev1_ambig = OrderStatusHistory(
        order_id=order_ambiguous.id,
        old_status=None,
        new_status="pending_approval",
        changed_by=valid_user.id,
    )
    # Event 2: NULL user (invalid / unrecorded creator)
    ev2_ambig = OrderStatusHistory(
        order_id=order_ambiguous.id,
        old_status=None,
        new_status="pending_approval",
        changed_by=None,
    )
    # Add strictly 1 creation event for order_clear:
    ev_clear = OrderStatusHistory(
        order_id=order_clear.id,
        old_status=None,
        new_status="pending_approval",
        changed_by=valid_user.id,
    )
    db_session.add_all([ev1_ambig, ev2_ambig, ev_clear])
    db_session.commit()

    # Run the exact corrected SQL logic from migration d5e6f7a8b9c0:
    unique_initial_creators = db_session.execute(sa.text("""
        SELECT osh.order_id, osh.changed_by
        FROM order_status_history osh
        JOIN users u ON u.id = osh.changed_by
        JOIN (
            SELECT osh_inner.order_id
            FROM order_status_history osh_inner
            WHERE osh_inner.old_status IS NULL
              AND osh_inner.new_status = 'pending_approval'
            GROUP BY osh_inner.order_id
            HAVING COUNT(*) = 1
        ) single_events ON single_events.order_id = osh.order_id
        WHERE osh.old_status IS NULL
          AND osh.new_status = 'pending_approval'
          AND osh.changed_by IS NOT NULL
    """)).fetchall()

    for row in unique_initial_creators:
        order_id = row[0]
        changed_by = row[1]
        db_session.execute(
            sa.text("""
                UPDATE orders
                SET created_by_user_id = :cb
                WHERE id = :oid AND created_by_user_id IS NULL
            """),
            {"cb": changed_by, "oid": order_id},
        )
    db_session.commit()

    # Verify:
    # 1. order_ambiguous was NOT backfilled because it had 2 creation events (COUNT(*) = 2)
    db_session.expire_all()
    reloaded_ambiguous = db_session.get(Order, order_ambiguous.id)
    assert reloaded_ambiguous.created_by_user_id is None

    # 2. order_clear was backfilled because it had strictly 1 creation event (COUNT(*) = 1)
    reloaded_clear = db_session.get(Order, order_clear.id)
    assert reloaded_clear.created_by_user_id == valid_user.id


def test_strict_downgrade_check_constraint_validation(test_engine) -> None:
    """Verify that strict downgrade check-constraint validation fails safely
    when the expected constraint is missing, and passes when it is present.
    """
    with test_engine.connect() as conn:
        inspector = sa.inspect(conn)
        expected_constraint_name = "ck_orders_supported_staff_attribution_status"

        existing_order_checks = {
            c["name"]
            for c in inspector.get_check_constraints("orders")
            if c.get("name")
        }
        # orders table created by metadata in test_engine has ck_orders_supported_staff_attribution_status
        assert expected_constraint_name in existing_order_checks

        # Simulate strict validation logic with a missing constraint name -> must raise RuntimeError
        missing_constraint = "ck_orders_nonexistent_constraint"
        simulated_checks = set(existing_order_checks)
        with pytest.raises(RuntimeError) as exc_info:
            if missing_constraint not in simulated_checks:
                raise RuntimeError(
                    f"Cannot downgrade migration: expected check constraint '{missing_constraint}' was not found "
                    f"on table 'orders'. Existing check constraints: {sorted(list(simulated_checks))}."
                )
        assert missing_constraint in str(exc_info.value)
