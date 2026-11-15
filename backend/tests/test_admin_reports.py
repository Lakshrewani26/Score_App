from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any

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
    PaymentStatusHistory,
    Product,
    ProductCategory,
    StaffPartnerAssignment,
    StaffPaymentRecord,
    StaffProfile,
    StockRequest,
    StockRequestItem,
    StockRequestStatusHistory,
    User,
    Zone,
)

TEST_SECRET_KEY = "test-secret-key-score-app-admin-panel-minimum-32-chars-long"


@pytest.fixture(autouse=True)
def configure_test_jwt_secret(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(settings, "jwt_secret_key", TEST_SECRET_KEY)
    monkeypatch.setattr(settings, "jwt_algorithm", "HS256")
    monkeypatch.setattr(settings, "jwt_access_token_expire_minutes", 60)


@pytest.fixture
def test_db_engine():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture
def client(test_db_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_db_engine, expire_on_commit=False) as db:
            yield db

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)


@pytest.fixture
def seed_data(test_db_engine) -> dict[str, Any]:
    with Session(test_db_engine) as session:
        # 1. Admin
        admin = User(
            name="Report Admin",
            mobile="9876543210",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)

        # 2. Partner
        partner = User(
            name="Partner Dealer",
            mobile="9876543211",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner)
        session.flush()

        partner_profile = PartnerProfile(
            user_id=partner.id,
            business_name="Apex Motors",
            business_address="100 Ring Road, Pune",
            partner_code="APX-01",
        )
        session.add(partner_profile)

        # 3. Staff
        staff = User(
            name="Staff Agent",
            mobile="9876543212",
            password_hash=hash_password("staffSecret123"),
            role="staff",
            is_active=True,
        )
        session.add(staff)
        session.flush()

        staff_profile = StaffProfile(
            user_id=staff.id,
            staff_id="STF-01",
        )
        session.add(staff_profile)

        # 4. Customer
        customer = User(
            name="Customer Alice",
            mobile="9876543213",
            password_hash=hash_password("custSecret123"),
            role="customer",
            is_active=True,
        )
        session.add(customer)
        session.flush()

        customer_profile = CustomerProfile(
            user_id=customer.id,
            state="Maharashtra",
            city="Pune",
            segment="Retail",
        )
        session.add(customer_profile)

        # 5. Categories
        cat_active = ProductCategory(
            name="Engine Parts",
            description="All active engine components",
            is_active=True,
        )
        cat_inactive = ProductCategory(
            name="Legacy Accessories",
            description="Discontinued category",
            is_active=False,
        )
        session.add_all([cat_active, cat_inactive])
        session.flush()

        # 6. Products
        p1 = Product(
            category_id=cat_active.id,
            product_code="ENG-001",
            name="Spark Plug",
            vehicle_type="2-Wheeler",
            price=Decimal("150.00"),
            is_active=True,
        )
        p2 = Product(
            category_id=cat_active.id,
            product_code="ENG-002",
            name="Piston Ring",
            vehicle_type="2-Wheeler",
            price=Decimal("500.00"),
            is_active=True,
        )
        p3_inactive = Product(
            category_id=cat_active.id,
            product_code="ENG-003",
            name="Old Gasket",
            vehicle_type="Both",
            price=Decimal("80.00"),
            is_active=False,
        )
        p4_null_price = Product(
            category_id=cat_active.id,
            product_code="ENG-004",
            name="Custom Valve",
            vehicle_type="3-Wheeler",
            price=None,
            is_active=True,
        )
        p5_in_inactive_cat = Product(
            category_id=cat_inactive.id,
            product_code="ACC-001",
            name="Chrome Mirror",
            vehicle_type="Both",
            price=Decimal("250.00"),
            is_active=True,
        )
        session.add_all([p1, p2, p3_inactive, p4_null_price, p5_in_inactive_cat])
        session.flush()

        now = datetime.now(timezone.utc)

        # 7. Orders with distinct statuses and creation dates
        # Order 1: pending_approval (today)
        order1 = Order(
            order_number="ORD-202610-001",
            partner_id=partner.id,
            status="pending_approval",
            created_at=now,
        )
        # Order 2: approved_processing (yesterday)
        order2 = Order(
            order_number="ORD-202610-002",
            partner_id=partner.id,
            status="approved_processing",
            created_at=now - timedelta(days=1),
        )
        # Order 3: dispatched (2 days ago)
        order3 = Order(
            order_number="ORD-202610-003",
            partner_id=partner.id,
            status="dispatched",
            created_at=now - timedelta(days=2),
        )
        # Order 4: delivered (5 days ago)
        order4 = Order(
            order_number="ORD-202610-004",
            partner_id=partner.id,
            status="delivered",
            created_at=now - timedelta(days=5),
        )
        # Order 5: rejected (10 days ago)
        order5 = Order(
            order_number="ORD-202610-005",
            partner_id=partner.id,
            status="rejected",
            created_at=now - timedelta(days=10),
        )
        # Order 6: delivered (45 days ago, outside 30d window)
        order6 = Order(
            order_number="ORD-202609-001",
            partner_id=partner.id,
            status="delivered",
            created_at=now - timedelta(days=45),
        )

        session.add_all([order1, order2, order3, order4, order5, order6])
        session.flush()

        # Order items (Order 1 has 2 items to verify distinct order counts)
        item1_a = OrderItem(order_id=order1.id, product_id=p1.id, quantity=2, unit_price=Decimal("150.00"))
        item1_b = OrderItem(order_id=order1.id, product_id=p2.id, quantity=1, unit_price=Decimal("500.00"))
        item2 = OrderItem(order_id=order2.id, product_id=p1.id, quantity=4, unit_price=Decimal("150.00"))
        item3 = OrderItem(order_id=order3.id, product_id=p2.id, quantity=2, unit_price=Decimal("500.00"))
        item4 = OrderItem(order_id=order4.id, product_id=p1.id, quantity=10, unit_price=Decimal("150.00"))
        item5 = OrderItem(order_id=order5.id, product_id=p2.id, quantity=1, unit_price=Decimal("500.00"))
        item6 = OrderItem(order_id=order6.id, product_id=p1.id, quantity=5, unit_price=Decimal("150.00"))
        session.add_all([item1_a, item1_b, item2, item3, item4, item5, item6])

        # 8. Stock Requests
        sr1 = StockRequest(
            request_number="REQ-202610-001",
            partner_id=partner.id,
            status="pending_approval",
            created_at=now,
        )
        sr2 = StockRequest(
            request_number="REQ-202610-002",
            partner_id=partner.id,
            status="approved",
            created_at=now - timedelta(days=2),
        )
        sr3 = StockRequest(
            request_number="REQ-202610-003",
            partner_id=partner.id,
            status="rejected",
            created_at=now - timedelta(days=8),
        )
        sr4_old = StockRequest(
            request_number="REQ-202609-001",
            partner_id=partner.id,
            status="approved",
            created_at=now - timedelta(days=40),
        )
        session.add_all([sr1, sr2, sr3, sr4_old])
        session.commit()

        admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
        partner_token = create_access_token(subject=str(partner.id), role="partner", mobile=partner.mobile)
        staff_token = create_access_token(subject=str(staff.id), role="staff", mobile=staff.mobile)
        customer_token = create_access_token(subject=str(customer.id), role="customer", mobile=customer.mobile)

        return {
            "admin_id": admin.id,
            "admin_token": admin_token,
            "partner_token": partner_token,
            "staff_token": staff_token,
            "customer_token": customer_token,
            "now": now,
        }


def _auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


# ==============================================================================
# TEST CASES
# ==============================================================================

def test_admin_can_retrieve_report_overview(client: TestClient, seed_data: dict[str, Any]) -> None:
    """1. Admin can retrieve report overview."""
    resp = client.get(
        "/api/v1/admin/reports/overview",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "generated_at" in data
    assert "filter" in data
    assert "overview" in data
    assert "catalogue_summary" in data
    assert "order_status_distribution" in data
    assert "stock_request_status_distribution" in data
    assert "order_trends" in data
    assert "unsupported_metrics" in data


def test_unauthenticated_access_is_rejected(client: TestClient) -> None:
    """2. Unauthenticated access is rejected with 401."""
    resp = client.get("/api/v1/admin/reports/overview")
    assert resp.status_code == 401


def test_non_admin_roles_rejected(client: TestClient, seed_data: dict[str, Any]) -> None:
    """3. Customer, Partner, and Staff tokens cannot access Admin reporting."""
    for role, token in [
        ("customer", seed_data["customer_token"]),
        ("partner", seed_data["partner_token"]),
        ("staff", seed_data["staff_token"]),
    ]:
        resp = client.get("/api/v1/admin/reports/overview", headers=_auth_header(token))
        assert resp.status_code == 403, f"Expected 403 for {role}, got {resp.status_code}"


def test_empty_database_produces_accurate_zero_counts(client: TestClient, test_db_engine) -> None:
    """4. Empty database produces accurate zero counts for supported metrics."""
    with Session(test_db_engine) as session:
        admin = User(
            name="Empty Admin",
            mobile="9999999999",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)
        session.commit()
        token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)

    resp = client.get("/api/v1/admin/reports/overview", headers=_auth_header(token))
    assert resp.status_code == 200
    data = resp.json()

    overview = data["overview"]
    assert overview["total_orders"] == 0
    assert overview["orders_pending_approval"] == 0
    assert overview["orders_processing"] == 0
    assert overview["orders_dispatched"] == 0
    assert overview["orders_delivered"] == 0
    assert overview["orders_rejected"] == 0
    assert overview["total_stock_requests"] == 0
    assert overview["stock_requests_pending_approval"] == 0
    assert overview["stock_requests_approved"] == 0
    assert overview["stock_requests_rejected"] == 0
    assert float(overview["total_order_value"]) == 0.0

    cat = data["catalogue_summary"]
    assert cat["total_products"] == 0
    assert cat["active_products"] == 0
    assert cat["inactive_products"] == 0
    assert cat["total_categories"] == 0
    assert cat["active_categories"] == 0
    assert cat["inactive_categories"] == 0
    assert cat["products_with_null_price"] == 0


def test_order_counts_match_actual_records(client: TestClient, seed_data: dict[str, Any]) -> None:
    """5. Order counts match actual records in the requested date preset."""
    # Last 30 days should include orders 1-5 (created within 10 days), but exclude order 6 (created 45 days ago)
    resp = client.get(
        "/api/v1/admin/reports/overview?preset=30d",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    overview = resp.json()["overview"]
    assert overview["total_orders"] == 5
    assert overview["orders_pending_approval"] == 1
    assert overview["orders_processing"] == 1
    assert overview["orders_dispatched"] == 1
    assert overview["orders_delivered"] == 1
    assert overview["orders_rejected"] == 1


def test_order_status_distribution_uses_current_status_values(client: TestClient, seed_data: dict[str, Any]) -> None:
    """6. Order status distribution uses current status values and labels."""
    resp = client.get(
        "/api/v1/admin/reports/overview?preset=30d",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    dist = resp.json()["order_status_distribution"]
    status_map = {item["status"]: item["count"] for item in dist}
    assert status_map["pending_approval"] == 1
    assert status_map["approved_processing"] == 1
    assert status_map["dispatched"] == 1
    assert status_map["delivered"] == 1
    assert status_map["rejected"] == 1


def test_multiple_order_items_do_not_inflate_order_counts(client: TestClient, seed_data: dict[str, Any]) -> None:
    """7. Multiple order items do not inflate order counts (distinct count)."""
    # Order 1 has 2 items: item1_a and item1_b
    resp = client.get(
        "/api/v1/admin/reports/overview?preset=7d",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    # Within last 7 days: Order 1, 2, 3, 4 (4 orders total)
    assert resp.json()["overview"]["total_orders"] == 4


def test_date_filtering_includes_and_excludes_boundary_records(client: TestClient, seed_data: dict[str, Any]) -> None:
    """8. Date filtering includes and excludes the correct boundary records."""
    now = seed_data["now"]
    # Filter only today to yesterday
    from_date = (now - timedelta(days=1)).strftime("%Y-%m-%d")
    to_date = now.strftime("%Y-%m-%d")

    resp = client.get(
        f"/api/v1/admin/reports/overview?date_from={from_date}&date_to={to_date}",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    overview = resp.json()["overview"]
    # Only Order 1 (today) and Order 2 (yesterday) should be included
    assert overview["total_orders"] == 2
    assert overview["orders_pending_approval"] == 1
    assert overview["orders_processing"] == 1
    assert overview["orders_dispatched"] == 0


def test_interval_grouping_daily_weekly_monthly(client: TestClient, seed_data: dict[str, Any]) -> None:
    """9. Daily, weekly, monthly intervals behave correctly."""
    now = seed_data["now"]
    from_date = (now - timedelta(days=20)).strftime("%Y-%m-%d")
    to_date = now.strftime("%Y-%m-%d")

    # Daily
    resp_daily = client.get(
        f"/api/v1/admin/reports/overview?date_from={from_date}&date_to={to_date}&interval=daily",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp_daily.status_code == 200
    trends_daily = resp_daily.json()["order_trends"]
    assert len(trends_daily) == 21  # 20 days span inclusive = 21 daily buckets

    # Weekly
    resp_weekly = client.get(
        f"/api/v1/admin/reports/overview?date_from={from_date}&date_to={to_date}&interval=weekly",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp_weekly.status_code == 200
    trends_weekly = resp_weekly.json()["order_trends"]
    assert len(trends_weekly) >= 3

    # Monthly
    resp_monthly = client.get(
        f"/api/v1/admin/reports/overview?date_from={from_date}&date_to={to_date}&interval=monthly",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp_monthly.status_code == 200
    trends_monthly = resp_monthly.json()["order_trends"]
    assert len(trends_monthly) >= 1


def test_empty_periods_generate_zero_buckets(client: TestClient, seed_data: dict[str, Any]) -> None:
    """10. Empty periods are handled correctly with zero count buckets."""
    now = seed_data["now"]
    # 3 days ago to 4 days ago had no orders created (orders were at 0, 1, 2, 5, 10 days ago)
    d3 = (now - timedelta(days=3)).strftime("%Y-%m-%d")
    d4 = (now - timedelta(days=4)).strftime("%Y-%m-%d")

    resp = client.get(
        f"/api/v1/admin/reports/overview?date_from={d4}&date_to={d3}&interval=daily",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    trends = resp.json()["order_trends"]
    assert len(trends) == 2
    for pt in trends:
        assert pt["count"] == 0
        assert float(pt["total_value"]) == 0.0


def test_stock_request_counts_and_distribution(client: TestClient, seed_data: dict[str, Any]) -> None:
    """11. Stock request counts and status distribution are accurate."""
    resp = client.get(
        "/api/v1/admin/reports/overview?preset=30d",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    overview = resp.json()["overview"]
    assert overview["total_stock_requests"] == 3
    assert overview["stock_requests_pending_approval"] == 1
    assert overview["stock_requests_approved"] == 1
    assert overview["stock_requests_rejected"] == 1

    dist = resp.json()["stock_request_status_distribution"]
    dist_map = {item["status"]: item["count"] for item in dist}
    assert dist_map["pending_approval"] == 1
    assert dist_map["approved"] == 1
    assert dist_map["rejected"] == 1


def test_catalogue_summary_counts(client: TestClient, seed_data: dict[str, Any]) -> None:
    """12. Active/inactive product and category counts are accurate."""
    resp = client.get(
        "/api/v1/admin/reports/overview",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    cat = resp.json()["catalogue_summary"]
    assert cat["total_products"] == 5
    # Active products: p1, p2, p4, p5 = 4
    assert cat["active_products"] == 4
    # Inactive products: p3 = 1
    assert cat["inactive_products"] == 1
    assert cat["total_categories"] == 2
    assert cat["active_categories"] == 1
    assert cat["inactive_categories"] == 1


def test_null_priced_products_counted_correctly(client: TestClient, seed_data: dict[str, Any]) -> None:
    """13. Null-priced products are counted correctly and not coerced to zero."""
    resp = client.get(
        "/api/v1/admin/reports/overview",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    cat = resp.json()["catalogue_summary"]
    # Product 4 has price=None
    assert cat["products_with_null_price"] == 1


def test_inactive_category_handling_documented_rule(client: TestClient, seed_data: dict[str, Any]) -> None:
    """14. Inactive-category handling matches the documented rule."""
    resp = client.get(
        "/api/v1/admin/reports/overview",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    cat = resp.json()["catalogue_summary"]
    # Total active products includes active products across categories (p5 is active in inactive category)
    assert cat["active_products"] == 4
    assert cat["inactive_categories"] == 1


def test_invalid_date_ranges_rejected(client: TestClient, seed_data: dict[str, Any]) -> None:
    """15. Invalid date ranges are rejected with 400."""
    # date_from after date_to
    resp = client.get(
        "/api/v1/admin/reports/overview?date_from=2026-10-25&date_to=2026-10-20",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 400
    assert "Invalid date range" in resp.json()["detail"]

    # Malformed date string
    resp2 = client.get(
        "/api/v1/admin/reports/overview?date_from=not-a-date",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp2.status_code == 400
    assert "Invalid date format" in resp2.json()["detail"]


def test_unsupported_interval_and_preset_rejected(client: TestClient, seed_data: dict[str, Any]) -> None:
    """16. Unsupported intervals and presets are rejected with 400."""
    resp = client.get(
        "/api/v1/admin/reports/overview?interval=hourly",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 400
    assert "Unsupported interval" in resp.json()["detail"]

    resp2 = client.get(
        "/api/v1/admin/reports/overview?preset=last_decade",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp2.status_code == 400
    assert "Unsupported preset" in resp2.json()["detail"]


def test_all_time_preset_includes_all_records(client: TestClient, seed_data: dict[str, Any]) -> None:
    """17. All time preset includes all orders across all dates."""
    resp = client.get(
        "/api/v1/admin/reports/overview?preset=all_time",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    overview = resp.json()["overview"]
    assert overview["total_orders"] == 6
    assert overview["total_stock_requests"] == 4


def test_reporting_requests_are_strictly_read_only(client: TestClient, seed_data: dict[str, Any], test_db_engine) -> None:
    """18. Reporting requests do not mutate orders, products, categories, or requests."""
    with Session(test_db_engine) as session:
        initial_order_count = session.query(Order).count()
        initial_prod_count = session.query(Product).count()
        initial_cat_count = session.query(ProductCategory).count()
        initial_sr_count = session.query(StockRequest).count()

    resp = client.get(
        "/api/v1/admin/reports/overview?preset=all_time",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200

    with Session(test_db_engine) as session:
        assert session.query(Order).count() == initial_order_count
        assert session.query(Product).count() == initial_prod_count
        assert session.query(ProductCategory).count() == initial_cat_count
        assert session.query(StockRequest).count() == initial_sr_count


def test_duplicate_product_codes_in_different_categories(client: TestClient, seed_data: dict[str, Any], test_db_engine) -> None:
    """19. Metrics remain correct with duplicate product codes across categories."""
    with Session(test_db_engine) as session:
        # Add another product with same product_code ENG-001 in inactive category
        dup_product = Product(
            category_id=session.query(ProductCategory).filter_by(is_active=False).first().id,
            product_code="ENG-001",
            name="Different Product Same Code",
            vehicle_type="2-Wheeler",
            price=Decimal("300.00"),
            is_active=True,
        )
        session.add(dup_product)
        session.commit()

    resp = client.get(
        "/api/v1/admin/reports/overview",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    cat = resp.json()["catalogue_summary"]
    # Total products was 5, now 6
    assert cat["total_products"] == 6
    assert cat["active_products"] == 5


def test_unsupported_metrics_are_explicitly_declared(client: TestClient, seed_data: dict[str, Any]) -> None:
    """20. Unsupported metrics are explicitly declared rather than fabricated."""
    resp = client.get(
        "/api/v1/admin/reports/overview",
        headers=_auth_header(seed_data["admin_token"]),
    )
    assert resp.status_code == 200
    unsupported = resp.json()["unsupported_metrics"]
    assert "points_balances_and_history" in unsupported
    assert "qr_scans_and_batches" in unsupported
    assert "payment_gateway_transactions" in unsupported
    assert "inventory_stock_quantities" in unsupported


# ---------------------------------------------------------------------------
# Phase 1: Financial and Operational Accuracy Tests
# ---------------------------------------------------------------------------

def test_payment_lifecycle_approved_vs_unapproved(client: TestClient, test_db_engine) -> None:
    """Verify that only approved payments contribute to collected amounts across Zone, Staff, and Partner reports."""
    with Session(test_db_engine) as session:
        # 1. Admin
        admin = User(
            name="FinAdmin",
            mobile="9800000001",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)

        # 2. Zone
        zone = Zone(name="North Zone", description="North region")
        session.add(zone)
        session.flush()

        # 3. Staff
        staff_u = User(
            name="Finance Staff",
            mobile="9800000002",
            password_hash=hash_password("staffSecret123"),
            role="staff",
            is_active=True,
        )
        session.add(staff_u)
        session.flush()
        staff_prof = StaffProfile(user_id=staff_u.id, staff_id="STF-FIN-01")
        session.add(staff_prof)

        # 4. Partner with Zone
        partner_u = User(
            name="Finance Partner",
            mobile="9800000003",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner_u)
        session.flush()
        partner_prof = PartnerProfile(
            user_id=partner_u.id,
            business_name="North Auto",
            business_address="12 GT Road",
            partner_code="FIN-01",
            zone_id=zone.id,
        )
        session.add(partner_prof)

        # 5. Active Staff-Partner Assignment
        assignment = StaffPartnerAssignment(
            staff_id=staff_u.id,
            partner_id=partner_u.id,
            is_active=True,
        )
        session.add(assignment)

        # 6. Four Payments for assigned partner & staff: approved, recorded, rejected, voided
        now = datetime.now(timezone.utc)
        p_approved = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=partner_u.id,
            amount=Decimal("1500.00"),
            payment_method="cash",
            status="approved",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        p_recorded = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=partner_u.id,
            amount=Decimal("700.00"),
            payment_method="bank_transfer",
            status="recorded",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        p_rejected = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=partner_u.id,
            amount=Decimal("400.00"),
            payment_method="cheque",
            status="rejected",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        p_voided = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=partner_u.id,
            amount=Decimal("300.00"),
            payment_method="cash",
            status="voided",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        session.add_all([p_approved, p_recorded, p_rejected, p_voided])

        # 7. Unassigned Partner with approved and non-approved payments
        unassigned_u = User(
            name="Unassigned Partner",
            mobile="9800000004",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(unassigned_u)
        session.flush()
        unassigned_prof = PartnerProfile(
            user_id=unassigned_u.id,
            business_name="Unassigned Shop",
            business_address="No Zone Lane",
            partner_code="FIN-02",
            zone_id=None,
        )
        session.add(unassigned_prof)

        up_approved = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=unassigned_u.id,
            amount=Decimal("800.00"),
            payment_method="cash",
            status="approved",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        up_recorded = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=unassigned_u.id,
            amount=Decimal("500.00"),
            payment_method="cash",
            status="recorded",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        up_rejected = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=unassigned_u.id,
            amount=Decimal("200.00"),
            payment_method="cash",
            status="rejected",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        up_voided = StaffPaymentRecord(
            staff_id=staff_u.id,
            partner_id=unassigned_u.id,
            amount=Decimal("100.00"),
            payment_method="cash",
            status="voided",
            recorded_by=staff_u.id,
            recorded_at=now,
        )
        session.add_all([up_approved, up_recorded, up_rejected, up_voided])
        session.commit()

        token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
        zid = zone.id
        sid = staff_u.id
        pid = partner_u.id

    headers = _auth_header(token)

    # 1. Zone-Wise: only approved payments count
    resp_zone = client.get("/api/v1/admin/reports/zone-wise", headers=headers)
    assert resp_zone.status_code == 200
    z_items = resp_zone.json()["items"]
    target_zone = next((z for z in z_items if z["zone_id"] == zid), None)
    assert target_zone is not None
    assert target_zone["payment_count"] == 1
    assert Decimal(str(target_zone["total_payments_collected"])) == Decimal("1500.00")

    # Unassigned Zone check
    unassigned_zone = next((z for z in z_items if z["zone_id"] is None), None)
    assert unassigned_zone is not None
    assert unassigned_zone["payment_count"] == 1
    assert Decimal(str(unassigned_zone["total_payments_collected"])) == Decimal("800.00")

    # 2. Staff-Wise: only approved payments count
    resp_staff = client.get(f"/api/v1/admin/reports/staff-wise?staff_id={sid}", headers=headers)
    assert resp_staff.status_code == 200
    s_items = resp_staff.json()["items"]
    assert len(s_items) == 1
    # Staff collected 1500 (from assigned partner) + 800 (from unassigned partner) = 2300 approved
    # Wait, let's verify staff_wise query filters by StaffPaymentRecord.staff_id == sid:
    # both p_approved and up_approved were recorded by staff_u, so 2 approved payments = 2300.00
    assert s_items[0]["payment_count"] == 2
    assert Decimal(str(s_items[0]["total_payments_collected"])) == Decimal("2300.00")

    # 3. Partner-Wise: only approved payments count
    resp_partner = client.get(f"/api/v1/admin/reports/partner-wise?partner_id={pid}", headers=headers)
    assert resp_partner.status_code == 200
    p_items = resp_partner.json()["items"]
    assert len(p_items) == 1
    assert p_items[0]["payment_count"] == 1
    assert Decimal(str(p_items[0]["total_payments_made"])) == Decimal("1500.00")


@pytest.mark.parametrize(
    "test_status,should_include_value",
    [
        ("pending_approval", False),
        ("approved_processing", True),
        ("dispatched", True),
        ("delivered", True),
        ("rejected", False),
        ("cancelled", False),
    ],
)
def test_individual_order_statuses_value_semantics(
    client: TestClient, test_db_engine, test_status: str, should_include_value: bool
) -> None:
    """Verify each supported order status individually across all 5 endpoints:
    approved_processing, dispatched, delivered -> included in total_order_value (approved orders).
    pending_approval, rejected, cancelled -> excluded from total_order_value.
    """
    with Session(test_db_engine) as session:
        admin = User(
            name=f"StatusAdmin_{test_status}",
            mobile="9710000099",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)

        zone = Zone(name=f"Zone_{test_status}", description="Test zone")
        session.add(zone)
        session.flush()

        staff = User(
            name=f"Staff_{test_status}",
            mobile="9720000099",
            password_hash=hash_password("staffSecret123"),
            role="staff",
            is_active=True,
        )
        session.add(staff)
        session.flush()
        session.add(StaffProfile(user_id=staff.id, staff_id=f"STF-{test_status[:4]}"))

        partner = User(
            name=f"Partner_{test_status}",
            mobile="9730000099",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner)
        session.flush()
        session.add(PartnerProfile(
            user_id=partner.id,
            business_name=f"Biz_{test_status}",
            business_address=f"Area_{test_status}",
            partner_code=f"P-{test_status[:4]}",
            zone_id=zone.id,
        ))

        session.add(StaffPartnerAssignment(
            staff_id=staff.id,
            partner_id=partner.id,
            is_active=True,
        ))

        cat = ProductCategory(name=f"Cat_{test_status}")
        session.add(cat)
        session.flush()
        prod = Product(
            category_id=cat.id,
            product_code=f"PRD-{test_status[:4]}",
            name=f"Product {test_status}",
            vehicle_type="2-Wheeler",
            price=Decimal("250.00"),
            is_active=True,
        )
        session.add(prod)
        session.flush()

        order = Order(
            order_number=f"ORD-{test_status}-001",
            partner_id=partner.id,
            status=test_status,
            created_at=datetime.now(timezone.utc),
        )
        session.add(order)
        session.flush()
        session.add(OrderItem(order_id=order.id, product_id=prod.id, quantity=2, unit_price=Decimal("250.00")))
        session.commit()

        admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
        zid = zone.id
        sid = staff.id
        pid = partner.id

    headers = _auth_header(admin_token)
    expected_value = Decimal("500.00") if should_include_value else Decimal("0.00")

    # 1. Overview
    r_over = client.get("/api/v1/admin/reports/overview?preset=all_time", headers=headers)
    assert r_over.status_code == 200
    over_data = r_over.json()
    assert over_data["overview"]["total_orders"] == 1
    assert Decimal(str(over_data["overview"]["total_order_value"])) == expected_value

    # 2. Zone-Wise
    r_zone = client.get(f"/api/v1/admin/reports/zone-wise?zone_id={zid}", headers=headers)
    assert r_zone.status_code == 200
    z_data = r_zone.json()
    assert z_data["total_orders"] == 1
    assert Decimal(str(z_data["total_order_value"])) == expected_value
    assert Decimal(str(z_data["items"][0]["total_order_value"])) == expected_value

    # 3. Area-Wise
    r_area = client.get(f"/api/v1/admin/reports/area-wise?zone_id={zid}", headers=headers)
    assert r_area.status_code == 200
    a_data = r_area.json()
    assert a_data["total_areas"] == 1
    assert a_data["items"][0]["order_count"] == 1
    assert Decimal(str(a_data["items"][0]["total_order_value"])) == expected_value

    # 4. Staff-Wise
    r_staff = client.get(f"/api/v1/admin/reports/staff-wise?staff_id={sid}", headers=headers)
    assert r_staff.status_code == 200
    s_data = r_staff.json()
    assert s_data["items"][0]["order_count"] == 1
    assert Decimal(str(s_data["items"][0]["total_order_value"])) == expected_value

    # 5. Partner-Wise
    r_partner = client.get(f"/api/v1/admin/reports/partner-wise?partner_id={pid}", headers=headers)
    assert r_partner.status_code == 200
    p_data = r_partner.json()
    assert p_data["items"][0]["order_count"] == 1
    assert Decimal(str(p_data["items"][0]["total_order_value"])) == expected_value


def test_order_status_distribution_reconciles_with_total_orders(client: TestClient, test_db_engine) -> None:
    """Verify all 6 supported order statuses together, checking:
    1. Overview distribution includes cancelled orders.
    2. Sum of distribution counts equals total_orders.
    3. orders_cancelled is reported on overview.
    4. Valid order value excludes rejected and cancelled across all 5 endpoints.
    """
    with Session(test_db_engine) as session:
        admin = User(
            name="DistAdmin",
            mobile="9600000001",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)

        zone = Zone(name="Composite Zone", description="Zone with all statuses")
        session.add(zone)
        session.flush()

        staff = User(
            name="Composite Staff",
            mobile="9600000002",
            password_hash=hash_password("staffSecret123"),
            role="staff",
            is_active=True,
        )
        session.add(staff)
        session.flush()
        session.add(StaffProfile(user_id=staff.id, staff_id="STF-COMP-01"))

        partner = User(
            name="Composite Partner",
            mobile="9600000003",
            password_hash=hash_password("partnerSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner)
        session.flush()
        session.add(PartnerProfile(
            user_id=partner.id,
            business_name="Composite Motors",
            business_address="Area 51, Central",
            partner_code="COMP-01",
            zone_id=zone.id,
        ))

        session.add(StaffPartnerAssignment(
            staff_id=staff.id,
            partner_id=partner.id,
            is_active=True,
        ))

        cat = ProductCategory(name="Universal Parts")
        session.add(cat)
        session.flush()
        prod = Product(
            category_id=cat.id,
            product_code="UNI-01",
            name="Universal Bearing",
            vehicle_type="Both",
            price=Decimal("100.00"),
            is_active=True,
        )
        session.add(prod)
        session.flush()

        now = datetime.now(timezone.utc)
        statuses_with_amounts = [
            ("pending_approval", 1, Decimal("100.00")),
            ("approved_processing", 2, Decimal("200.00")),
            ("dispatched", 3, Decimal("300.00")),
            ("delivered", 4, Decimal("400.00")),
            ("rejected", 5, Decimal("500.00")),
            ("cancelled", 6, Decimal("600.00")),
        ]

        for st, qty, _ in statuses_with_amounts:
            o = Order(
                order_number=f"ORD-COMP-{st[:4].upper()}",
                partner_id=partner.id,
                status=st,
                created_at=now,
            )
            session.add(o)
            session.flush()
            session.add(OrderItem(order_id=o.id, product_id=prod.id, quantity=qty, unit_price=Decimal("100.00")))

        session.commit()

        admin_token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)
        zid = zone.id
        sid = staff.id
        pid = partner.id

    headers = _auth_header(admin_token)

    # Approved total value: 200 (processing) + 300 (dispatched) + 400 (delivered) = 900.00
    # Pending approval (100), Rejected (500), and Cancelled (600) excluded!
    expected_approved_value = Decimal("900.00")

    # 1. Overview
    resp_over = client.get("/api/v1/admin/reports/overview?preset=all_time", headers=headers)
    assert resp_over.status_code == 200
    over_body = resp_over.json()
    ov = over_body["overview"]
    assert ov["total_orders"] == 6
    assert ov["orders_pending_approval"] == 1
    assert ov["orders_processing"] == 1
    assert ov["orders_dispatched"] == 1
    assert ov["orders_delivered"] == 1
    assert ov["orders_rejected"] == 1
    assert ov["orders_cancelled"] == 1
    assert Decimal(str(ov["total_order_value"])) == expected_approved_value

    # Check status distribution
    dist = over_body["order_status_distribution"]
    assert len(dist) == 6
    dist_map = {item["status"]: item["count"] for item in dist}
    assert dist_map["pending_approval"] == 1
    assert dist_map["approved_processing"] == 1
    assert dist_map["dispatched"] == 1
    assert dist_map["delivered"] == 1
    assert dist_map["rejected"] == 1
    assert dist_map["cancelled"] == 1
    assert sum(dist_map.values()) == ov["total_orders"] == 6

    # 2. Zone-Wise
    resp_zone = client.get(f"/api/v1/admin/reports/zone-wise?zone_id={zid}", headers=headers)
    assert resp_zone.status_code == 200
    z_body = resp_zone.json()
    assert z_body["total_orders"] == 6
    assert Decimal(str(z_body["total_order_value"])) == expected_approved_value
    assert z_body["items"][0]["order_count"] == 6
    assert Decimal(str(z_body["items"][0]["total_order_value"])) == expected_approved_value

    # 3. Area-Wise
    resp_area = client.get(f"/api/v1/admin/reports/area-wise?zone_id={zid}", headers=headers)
    assert resp_area.status_code == 200
    a_body = resp_area.json()
    assert a_body["items"][0]["order_count"] == 6
    assert Decimal(str(a_body["items"][0]["total_order_value"])) == expected_approved_value

    # 4. Staff-Wise
    resp_staff = client.get(f"/api/v1/admin/reports/staff-wise?staff_id={sid}", headers=headers)
    assert resp_staff.status_code == 200
    s_body = resp_staff.json()
    assert s_body["items"][0]["order_count"] == 6
    assert Decimal(str(s_body["items"][0]["total_order_value"])) == expected_approved_value

    # 5. Partner-Wise
    resp_partner = client.get(f"/api/v1/admin/reports/partner-wise?partner_id={pid}", headers=headers)
    assert resp_partner.status_code == 200
    p_body = resp_partner.json()
    assert p_body["items"][0]["order_count"] == 6
    assert Decimal(str(p_body["items"][0]["total_order_value"])) == expected_approved_value
