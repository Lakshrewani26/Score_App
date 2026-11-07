from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import io
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
    PointsRule,
    PointTransaction,
    Product,
    ProductCategory,
    QrBatch,
    QrCode,
    StaffProfile,
    User,
)
from app.services.pdf_service import generate_order_pdf

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
    Base.metadata.create_all(bind=engine)
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine) -> Generator[Session, None, None]:
    with Session(test_engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def client(test_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine, expire_on_commit=False) as db:
            yield db

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def seed_data(db_session: Session):
    admin = User(
        name="Admin User",
        mobile="9000000001",
        password_hash=hash_password("admin123"),
        role="admin",
        is_active=True,
    )
    partner = User(
        name="Partner User",
        mobile="9000000002",
        password_hash=hash_password("partner123"),
        role="partner",
        is_active=True,
    )
    customer = User(
        name="Customer User",
        mobile="9000000003",
        password_hash=hash_password("customer123"),
        role="customer",
        is_active=True,
    )
    db_session.add_all([admin, partner, customer])
    db_session.flush()

    partner_profile = PartnerProfile(
        user_id=partner.id,
        business_name="Apex Motors",
        business_address="123 Industrial Way",
        partner_code="PRT-APEX",
        discount_percentage=Decimal("10.00"),
    )
    customer_profile = CustomerProfile(
        user_id=customer.id,
        state="Maharashtra",
        city="Pune",
        segment="Retail",
    )
    cat = ProductCategory(name="Brakes", description="Braking systems")
    db_session.add_all([partner_profile, customer_profile, cat])
    db_session.flush()

    p1 = Product(
        name="Disc Brake Pad",
        product_code="BRK-001",
        category_id=cat.id,
        vehicle_type="2-Wheeler",
        price=Decimal("1000.00"),
        is_active=True,
    )
    p2 = Product(
        name="Clutch Cable",
        product_code="CLT-002",
        category_id=cat.id,
        vehicle_type="2-Wheeler",
        price=Decimal("500.00"),
        is_active=True,
    )
    db_session.add_all([p1, p2])
    db_session.flush()

    batch = QrBatch(
        batch_number="BATCH-TEST-001",
        qr_type="product",
        description="Initial seed batch",
        quantity=2,
        status="completed",
        created_by=admin.id,
    )
    db_session.add(batch)
    db_session.flush()

    qr_p1 = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="A" * 32,
        code_data=f"score://qr/v1?token={'A'*32}&type=product",
        points_awarded=50,
        product_id=p1.id,
        status="active",
    )
    qr_p2 = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="B" * 32,
        code_data=f"score://qr/v1?token={'B'*32}&type=product",
        points_awarded=30,
        product_id=p2.id,
        status="active",
    )
    db_session.add_all([qr_p1, qr_p2])
    db_session.commit()

    return {
        "admin": admin,
        "partner": partner,
        "customer": customer,
        "product1": p1,
        "product2": p2,
        "qr1": qr_p1,
        "qr2": qr_p2,
    }


def admin_headers(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role="admin", mobile=user.mobile)
    return {"Authorization": f"Bearer {token}"}


def partner_headers(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role="partner", mobile=user.mobile)
    return {"Authorization": f"Bearer {token}"}


def customer_headers(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role="customer", mobile=user.mobile)
    return {"Authorization": f"Bearer {token}"}


# =============================================================================
# Feature G: Advanced Loyalty Point Rules Tests
# =============================================================================


def test_loyalty_rules_customer_and_partner_creation(client: TestClient, seed_data):
    admin = seed_data["admin"]
    h = admin_headers(admin)

    # 1. Create rule for Customer QR scan
    cust_rule_payload = {
        "rule_name": "Customer QR Scan Rule",
        "category": "customer_qr_scan",
        "points_awarded": 50,
        "conversion_rate": "1.00",
        "point_value": "1.50",
        "is_active": True,
    }
    res_c = client.post("/api/v1/admin/points-rules", json=cust_rule_payload, headers=h)
    assert res_c.status_code == 201
    c_data = res_c.json()
    assert c_data["category"] == "customer_qr_scan"
    assert c_data["points_awarded"] == 50
    assert float(c_data["point_value"]) == 1.50
    assert c_data["version"] == 1
    assert c_data["parent_rule_id"] is None

    # 2. Create rule for Partner QR scan
    part_rule_payload = {
        "rule_name": "Partner QR Scan Rule",
        "category": "partner_qr_scan",
        "points_awarded": 100,
        "conversion_rate": "1.00",
        "point_value": "2.00",
        "is_active": True,
    }
    res_p = client.post("/api/v1/admin/points-rules", json=part_rule_payload, headers=h)
    assert res_p.status_code == 201
    p_data = res_p.json()
    assert p_data["category"] == "partner_qr_scan"
    assert p_data["points_awarded"] == 100
    assert float(p_data["point_value"]) == 2.00
    assert p_data["version"] == 1


def test_loyalty_rule_versioning_and_history(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    h = admin_headers(admin)

    # 1. Create initial rule (version 1)
    res_init = client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Initial Partner Rule",
            "category": "partner_qr_scan",
            "points_awarded": 50,
            "point_value": "1.00",
            "is_active": True,
        },
        headers=h,
    )
    assert res_init.status_code == 201
    init_data = res_init.json()
    v1_id = init_data["id"]
    assert init_data["version"] == 1
    assert init_data["parent_rule_id"] is None
    assert init_data["is_current"] is True

    # 2. Update rule (creates a brand new record for version 2; leaves version 1 immutable)
    res_update = client.put(
        f"/api/v1/admin/points-rules/{v1_id}",
        json={
            "rule_name": "Updated Partner Rule v2",
            "points_awarded": 75,
            "point_value": "1.25",
        },
        headers=h,
    )
    assert res_update.status_code == 200
    up_data = res_update.json()
    v2_id = up_data["id"]
    assert v2_id != v1_id  # Immutable versioning: new row created!
    assert up_data["version"] == 2
    assert up_data["parent_rule_id"] == v1_id
    assert up_data["points_awarded"] == 75
    assert up_data["is_current"] is True

    # 3. Direct DB verification: original row v1 MUST remain intact and unmutated
    db_session.expire_all()
    v1_db = db_session.query(PointsRule).filter(PointsRule.id == v1_id).one()
    assert v1_db.version == 1
    assert v1_db.points_awarded == 50
    assert v1_db.rule_name == "Initial Partner Rule"
    assert v1_db.is_current is False

    # 4. Retrieve history using root ID (v1_id)
    res_hist = client.get(f"/api/v1/admin/points-rules/{v1_id}/history", headers=h)
    assert res_hist.status_code == 200
    hist_data = res_hist.json()
    assert hist_data["rule_id"] == v1_id
    assert hist_data["current_version"] == 2
    assert len(hist_data["history"]) == 2
    # History returned ordered descending by version
    assert hist_data["history"][0]["id"] == v2_id
    assert hist_data["history"][0]["version"] == 2
    assert hist_data["history"][0]["points_awarded"] == 75
    assert hist_data["history"][0]["parent_rule_id"] == v1_id
    assert hist_data["history"][0]["is_current"] is True

    assert hist_data["history"][1]["id"] == v1_id
    assert hist_data["history"][1]["version"] == 1
    assert hist_data["history"][1]["points_awarded"] == 50
    assert hist_data["history"][1]["parent_rule_id"] is None
    assert hist_data["history"][1]["is_current"] is False

    # 5. History can also be queried using the child's id (v2_id)
    res_hist_child = client.get(f"/api/v1/admin/points-rules/{v2_id}/history", headers=h)
    assert res_hist_child.status_code == 200
    assert res_hist_child.json()["history"] == hist_data["history"]

    # 6. Listing rules without include_history returns only the current active version
    res_list = client.get("/api/v1/admin/points-rules?category=partner_qr_scan", headers=h)
    assert res_list.status_code == 200
    items = res_list.json()["items"]
    assert len(items) == 1
    assert items[0]["id"] == v2_id
    assert items[0]["is_current"] is True


def test_immutable_rule_versioning_preserves_historical_transactions(
    client: TestClient, seed_data, db_session: Session
):
    admin = seed_data["admin"]
    partner = seed_data["partner"]
    h_admin = admin_headers(admin)
    h_partner = partner_headers(partner)
    batch = db_session.query(QrBatch).first()

    # 1. Create initial rule (v1) awarding 45 points
    res_v1 = client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Partner Scan Rule v1",
            "category": "partner_qr_scan",
            "points_awarded": 45,
            "is_active": True,
        },
        headers=h_admin,
    )
    assert res_v1.status_code == 201
    v1_id = res_v1.json()["id"]

    # 2. Partner scans QR code 1 under Rule v1
    qr_1 = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="HIST_TEST_QR_001" + "A" * 16,
        code_data="score://qr/v1?token=HIST_TEST_QR_001",
        status="active",
    )
    db_session.add(qr_1)
    db_session.commit()

    scan1_res = client.post("/api/v1/qr/scan", json={"token": qr_1.token}, headers=h_partner)
    assert scan1_res.status_code == 200
    assert scan1_res.json()["points_awarded"] == 45

    # Check that transaction references v1_id
    db_session.expire_all()
    tx1 = db_session.query(PointTransaction).filter_by(qr_token=qr_1.token).one()
    assert tx1.points_rule_id == v1_id
    assert tx1.points_awarded == 45

    # 3. Admin creates Rule v2 awarding 90 points
    res_v2 = client.put(
        f"/api/v1/admin/points-rules/{v1_id}",
        json={
            "rule_name": "Partner Scan Rule v2",
            "points_awarded": 90,
        },
        headers=h_admin,
    )
    assert res_v2.status_code == 200
    v2_id = res_v2.json()["id"]
    assert v2_id != v1_id

    # 4. CRITICAL: Historical transaction tx1 MUST still reference v1_id,
    # and the v1 record in DB must STILL have version=1 and points_awarded=45
    db_session.expire_all()
    tx1_check = db_session.query(PointTransaction).filter_by(qr_token=qr_1.token).one()
    assert tx1_check.points_rule_id == v1_id
    assert tx1_check.points_awarded == 45

    v1_check = db_session.query(PointsRule).filter_by(id=v1_id).one()
    assert v1_check.version == 1
    assert v1_check.points_awarded == 45
    assert v1_check.is_current is False

    # 5. Partner scans QR code 2 under Rule v2
    qr_2 = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="HIST_TEST_QR_002" + "B" * 16,
        code_data="score://qr/v1?token=HIST_TEST_QR_002",
        status="active",
    )
    db_session.add(qr_2)
    db_session.commit()

    scan2_res = client.post("/api/v1/qr/scan", json={"token": qr_2.token}, headers=h_partner)
    assert scan2_res.status_code == 200
    assert scan2_res.json()["points_awarded"] == 90

    db_session.expire_all()
    tx2 = db_session.query(PointTransaction).filter_by(qr_token=qr_2.token).one()
    assert tx2.points_rule_id == v2_id
    assert tx2.points_awarded == 90


def test_future_dated_rule_version_leaves_current_rule_active_no_gap(
    client: TestClient, seed_data, db_session: Session
):
    admin = seed_data["admin"]
    partner = seed_data["partner"]
    h_admin = admin_headers(admin)
    h_partner = partner_headers(partner)
    batch = db_session.query(QrBatch).first()

    now = datetime.now(timezone.utc)
    yesterday = (now - timedelta(days=1)).isoformat()
    future_start = (now + timedelta(days=5)).isoformat()

    # 1. Create rule v1 active starting yesterday
    res_v1 = client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Active Current Rule",
            "category": "partner_qr_scan",
            "points_awarded": 50,
            "effective_from": yesterday,
            "is_active": True,
        },
        headers=h_admin,
    )
    assert res_v1.status_code == 201
    v1_id = res_v1.json()["id"]

    # 2. Update to v2 with a future effective_from date (5 days ahead)
    res_v2 = client.put(
        f"/api/v1/admin/points-rules/{v1_id}",
        json={
            "rule_name": "Future Promotional Rule",
            "points_awarded": 100,
            "effective_from": future_start,
        },
        headers=h_admin,
    )
    assert res_v2.status_code == 200
    v2_id = res_v2.json()["id"]

    # Verify v1's effective_to was set to future_start so there is NO GAP in coverage
    db_session.expire_all()
    v1_db = db_session.query(PointsRule).filter_by(id=v1_id).one()
    assert v1_db.effective_to is not None
    assert v1_db.effective_to.strftime("%Y-%m-%d") == (now + timedelta(days=5)).strftime("%Y-%m-%d")

    # 3. Scan a QR code TODAY: v1 is still effective and must award points
    qr_gap_test = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="NO_GAP_TEST_001" + "G" * 16,
        code_data="score://qr/v1?token=NO_GAP_TEST_001",
        status="active",
    )
    db_session.add(qr_gap_test)
    db_session.commit()

    scan_res = client.post("/api/v1/qr/scan", json={"token": qr_gap_test.token}, headers=h_partner)
    assert scan_res.status_code == 200
    # Awards 50 points from v1, confirming v1 remained active and wasn't deactivated prematurely!
    assert scan_res.json()["points_awarded"] == 50


def test_concurrent_rule_versioning_and_unique_constraint(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    h = admin_headers(admin)

    # 1. Create rule v1
    res = client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Root Rule",
            "category": "customer_qr_scan",
            "points_awarded": 30,
            "is_active": True,
        },
        headers=h,
    )
    assert res.status_code == 201
    root_id = res.json()["id"]

    # 2. Verify that database UniqueConstraint("parent_rule_id", "version") prevents duplicate versions
    rule_v2_a = PointsRule(
        rule_name="Concurrent Version A",
        category="customer_qr_scan",
        points_awarded=60,
        version=2,
        parent_rule_id=root_id,
        is_current=True,
    )
    rule_v2_b = PointsRule(
        rule_name="Concurrent Version B",
        category="customer_qr_scan",
        points_awarded=70,
        version=2,
        parent_rule_id=root_id,
        is_current=True,
    )
    db_session.add(rule_v2_a)
    db_session.commit()

    db_session.add(rule_v2_b)
    with pytest.raises(Exception):
        db_session.commit()
    db_session.rollback()


def test_points_rule_check_constraints_and_supported_categories(db_session: Session):
    from sqlalchemy.exc import IntegrityError

    # 1. All 7 categories must be accepted
    supported_categories = [
        "customer_qr_scan",
        "partner_qr_scan",
        "product_qr_scan",
        "invoice_qr_scan",
        "redemption",
        "customer_to_partner_transfer",
        "partner_to_staff_transfer",
    ]
    for idx, cat in enumerate(supported_categories):
        rule = PointsRule(
            rule_name=f"Rule {cat}",
            category=cat,
            points_awarded=10 * (idx + 1),
            conversion_rate=Decimal("1.00"),
            point_value=Decimal("1.50"),
            version=1,
            is_active=True,
        )
        db_session.add(rule)
    db_session.commit()

    # 2. Unsupported category must be rejected
    bad_rule = PointsRule(
        rule_name="Bad Category",
        category="crypto_token_scan",
        points_awarded=50,
        version=1,
    )
    db_session.add(bad_rule)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()

    # 3. Negative conversion rate must be rejected
    bad_cr = PointsRule(
        rule_name="Bad Conversion Rate",
        category="customer_qr_scan",
        points_awarded=10,
        conversion_rate=Decimal("-0.50"),
        version=1,
    )
    db_session.add(bad_cr)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()

    # 4. Negative point value must be rejected
    bad_pv = PointsRule(
        rule_name="Bad Point Value",
        category="customer_qr_scan",
        points_awarded=10,
        point_value=Decimal("-1.00"),
        version=1,
    )
    db_session.add(bad_pv)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()

    # 5. Version < 1 must be rejected
    bad_ver = PointsRule(
        rule_name="Bad Version",
        category="customer_qr_scan",
        points_awarded=10,
        version=0,
    )
    db_session.add(bad_ver)
    with pytest.raises(IntegrityError):
        db_session.commit()
    db_session.rollback()


def test_migration_postgresql_ddl_and_constraint_handling():
    import io
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations

    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "a1b2c3d4e5f6_features_g_and_h_loyalty_and_discounts.py"
    )
    spec = importlib.util.spec_from_file_location("feat_gh_mig", migration_path)
    assert spec is not None and spec.loader is not None
    mig = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mig)

    # Compile PostgreSQL DDL for upgrade()
    buf_up = io.StringIO()
    ctx_up = MigrationContext.configure(
        dialect_name="postgresql", opts={"as_sql": True, "output_buffer": buf_up}
    )
    mig.op = Operations(ctx_up)
    mig.upgrade()
    sql_up = buf_up.getvalue()

    # Verify upgrade drops the old constraint and creates the new 7-category constraint
    assert "ALTER TABLE points_rules DROP CONSTRAINT ck_points_rules_supported_rule_category" in sql_up
    assert (
        "ck_points_rules_supported_rule_category CHECK (category IN ('customer_qr_scan', 'partner_qr_scan', 'product_qr_scan', 'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', 'partner_to_staff_transfer'))"
        in sql_up
    )
    assert "ALTER TABLE points_rules ADD COLUMN is_current BOOLEAN DEFAULT true NOT NULL" in sql_up
    assert "uq_points_rules_parent_rule_id_version UNIQUE (parent_rule_id, version)" in sql_up
    assert "ck_points_rules_nonnegative_conversion_rate" in sql_up
    assert "ck_points_rules_nonnegative_point_value" in sql_up
    assert "ck_points_rules_positive_rule_version" in sql_up

    # Compile PostgreSQL DDL for downgrade()
    buf_down = io.StringIO()
    ctx_down = MigrationContext.configure(
        dialect_name="postgresql", opts={"as_sql": True, "output_buffer": buf_down}
    )
    mig.op = Operations(ctx_down)
    mig.downgrade()
    sql_down = buf_down.getvalue()

    # Verify downgrade drops new constraints and restores original 5-category constraint
    assert "ALTER TABLE points_rules DROP CONSTRAINT ck_points_rules_positive_rule_version" in sql_down
    assert "ALTER TABLE points_rules DROP CONSTRAINT ck_points_rules_nonnegative_point_value" in sql_down
    assert "ALTER TABLE points_rules DROP CONSTRAINT ck_points_rules_nonnegative_conversion_rate" in sql_down
    assert "ALTER TABLE points_rules DROP CONSTRAINT ck_points_rules_supported_rule_category" in sql_down
    assert (
        "ck_points_rules_supported_rule_category CHECK (category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', 'partner_to_staff_transfer'))"
        in sql_down
    )
    assert "ALTER TABLE points_rules DROP CONSTRAINT uq_points_rules_parent_rule_id_version" in sql_down
    assert "ALTER TABLE points_rules DROP COLUMN is_current" in sql_down


def test_live_postgresql_check_constraint_if_configured():
    import os
    pg_url = os.getenv("POSTGRES_TEST_URL")
    if not pg_url:
        pytest.skip("POSTGRES_TEST_URL environment variable is not set; skipping live PostgreSQL test.")

    pg_engine = create_engine(pg_url)
    with pg_engine.begin():
        Base.metadata.create_all(bind=pg_engine)
        with Session(pg_engine) as session:
            rule = PointsRule(
                rule_name="Live PG Cust",
                category="customer_qr_scan",
                points_awarded=10,
                version=1,
            )
            session.add(rule)
            session.commit()

            with pytest.raises(Exception):
                bad = PointsRule(
                    rule_name="Live PG Bad",
                    category="bad_cat",
                    points_awarded=10,
                    version=1,
                )
                session.add(bad)
                session.commit()


def test_admin_points_rule_effective_status_distinguishes_current_vs_future_vs_inactive(
    client: TestClient, seed_data
):
    admin = seed_data["admin"]
    h = admin_headers(admin)

    now = datetime.now(timezone.utc)
    yesterday = (now - timedelta(days=1)).isoformat()
    future_start = (now + timedelta(days=7)).isoformat()

    # 1. Create currently effective rule (v1)
    res_v1 = client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Standard Active Rule",
            "category": "customer_qr_scan",
            "points_awarded": 50,
            "effective_from": yesterday,
            "is_active": True,
        },
        headers=h,
    )
    assert res_v1.status_code == 201
    v1_data = res_v1.json()
    v1_id = v1_data["id"]
    assert v1_data["version"] == 1
    assert v1_data["is_current"] is True
    assert v1_data["effective_status"] == "currently_effective"
    assert v1_data["is_currently_effective"] is True
    assert v1_data["is_future_scheduled"] is False

    # 2. Publish future-dated version (v2) starting in 7 days
    res_v2 = client.put(
        f"/api/v1/admin/points-rules/{v1_id}",
        json={
            "rule_name": "Scheduled Monsoon Rule",
            "points_awarded": 100,
            "effective_from": future_start,
        },
        headers=h,
    )
    assert res_v2.status_code == 200
    v2_data = res_v2.json()
    assert v2_data["version"] == 2
    assert v2_data["is_current"] is True  # Latest published version in the family
    assert v2_data["effective_status"] == "future_scheduled"  # But NOT currently effective!
    assert v2_data["is_currently_effective"] is False
    assert v2_data["is_future_scheduled"] is True

    # 3. Query history: both versions distinguishable with respective statuses and effective version identified
    res_hist = client.get(f"/api/v1/admin/points-rules/{v1_id}/history", headers=h)
    assert res_hist.status_code == 200
    hist = res_hist.json()
    assert hist["latest_version"] == 2
    assert hist["effective_version"] == 1  # Version 1 is the one running today!
    assert len(hist["history"]) == 2

    v2_hist = hist["history"][0]
    assert v2_hist["version"] == 2
    assert v2_hist["is_current"] is True
    assert v2_hist["effective_status"] == "future_scheduled"
    assert v2_hist["is_currently_effective"] is False
    assert v2_hist["is_future_scheduled"] is True

    v1_hist = hist["history"][1]
    assert v1_hist["version"] == 1
    assert v1_hist["is_current"] is False
    assert v1_hist["effective_status"] == "currently_effective"
    assert v1_hist["is_currently_effective"] is True
    assert v1_hist["is_future_scheduled"] is False

    # 4. Deactivate v1: status changes to 'inactive'
    res_deact = client.post(
        f"/api/v1/admin/points-rules/{v1_id}/status",
        json={"is_active": False},
        headers=h,
    )
    assert res_deact.status_code == 200
    assert res_deact.json()["effective_status"] == "inactive"
    assert res_deact.json()["is_currently_effective"] is False


def test_downgrade_aborts_safely_when_feature_g_rules_exist():
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    import sqlalchemy as sa
    from sqlalchemy import create_engine

    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "a1b2c3d4e5f6_features_g_and_h_loyalty_and_discounts.py"
    )
    spec = importlib.util.spec_from_file_location("feat_gh_mig_dg", migration_path)
    assert spec is not None and spec.loader is not None
    mig = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mig)

    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        conn.exec_driver_sql("CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(150))")
        conn.exec_driver_sql("CREATE TABLE qr_codes (id INTEGER PRIMARY KEY, token VARCHAR(64))")
        conn.exec_driver_sql(
            "CREATE TABLE points_rules ("
            "id INTEGER PRIMARY KEY, "
            "rule_name VARCHAR(120), "
            "category VARCHAR(50), "
            "CONSTRAINT ck_points_rules_supported_rule_category CHECK ("
            "category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', 'partner_to_staff_transfer')"
            "))"
        )
        conn.exec_driver_sql("CREATE TABLE partner_profiles (user_id INTEGER PRIMARY KEY, business_name VARCHAR(200))")
        conn.exec_driver_sql("CREATE TABLE orders (id INTEGER PRIMARY KEY, order_number VARCHAR(50))")
        conn.exec_driver_sql("CREATE TABLE order_items (id INTEGER PRIMARY KEY, quantity INTEGER, unit_price NUMERIC)")

        with Operations.context(MigrationContext.configure(conn)):
            mig.upgrade()

        # Insert a rule using Feature G category 'customer_qr_scan'
        conn.execute(
            sa.text(
                "INSERT INTO points_rules (id, rule_name, category, version, is_current) "
                "VALUES (1, 'Customer QR Rule', 'customer_qr_scan', 1, 1)"
            )
        )

        # Downgrade must safely ABORT without deleting or corrupting the rule
        with Operations.context(MigrationContext.configure(conn)):
            with pytest.raises(RuntimeError) as exc_info:
                mig.downgrade()
            assert "Cannot safely downgrade migration 'a1b2c3d4e5f6': found 1 loyalty rule(s) using Feature G categories" in str(exc_info.value)

        # Assert data was preserved!
        row = conn.execute(sa.text("SELECT category FROM points_rules WHERE id = 1")).fetchone()
        assert row[0] == "customer_qr_scan"


def test_downgrade_aborts_safely_when_point_transactions_exist():
    import importlib.util
    from pathlib import Path
    from alembic.migration import MigrationContext
    from alembic.operations import Operations
    import sqlalchemy as sa
    from sqlalchemy import create_engine

    backend_dir = Path(__file__).resolve().parents[1]
    migration_path = (
        backend_dir
        / "migrations"
        / "versions"
        / "a1b2c3d4e5f6_features_g_and_h_loyalty_and_discounts.py"
    )
    spec = importlib.util.spec_from_file_location("feat_gh_mig_pt", migration_path)
    assert spec is not None and spec.loader is not None
    mig = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mig)

    engine = create_engine("sqlite://")
    with engine.begin() as conn:
        conn.exec_driver_sql("CREATE TABLE users (id INTEGER PRIMARY KEY, name VARCHAR(150))")
        conn.exec_driver_sql("CREATE TABLE qr_codes (id INTEGER PRIMARY KEY, token VARCHAR(64))")
        conn.exec_driver_sql(
            "CREATE TABLE points_rules ("
            "id INTEGER PRIMARY KEY, "
            "rule_name VARCHAR(120), "
            "category VARCHAR(50), "
            "CONSTRAINT ck_points_rules_supported_rule_category CHECK ("
            "category IN ('product_qr_scan', 'invoice_qr_scan', 'redemption', 'customer_to_partner_transfer', 'partner_to_staff_transfer')"
            "))"
        )
        conn.exec_driver_sql("CREATE TABLE partner_profiles (user_id INTEGER PRIMARY KEY, business_name VARCHAR(200))")
        conn.exec_driver_sql("CREATE TABLE orders (id INTEGER PRIMARY KEY, order_number VARCHAR(50))")
        conn.exec_driver_sql("CREATE TABLE order_items (id INTEGER PRIMARY KEY, quantity INTEGER, unit_price NUMERIC)")

        with Operations.context(MigrationContext.configure(conn)):
            mig.upgrade()

        # Seed foreign key targets
        conn.execute(sa.text("INSERT INTO users (id, name) VALUES (1, 'Test User')"))
        conn.execute(sa.text("INSERT INTO qr_codes (id, token) VALUES (1, 'QR123')"))
        conn.execute(sa.text("INSERT INTO points_rules (id, rule_name, category, version, is_current) VALUES (1, 'Legacy Scan', 'product_qr_scan', 1, 1)"))

        # Insert a point transaction
        conn.execute(
            sa.text(
                "INSERT INTO point_transactions (id, user_id, qr_code_id, qr_token, points_rule_id, points_awarded, qr_type, transaction_type) "
                "VALUES (1, 1, 1, 'QR123', 1, 50, 'product', 'qr_scan')"
            )
        )

        # Downgrade must safely ABORT without dropping point_transactions or corrupting history
        with Operations.context(MigrationContext.configure(conn)):
            with pytest.raises(RuntimeError) as exc_info:
                mig.downgrade()
            assert "found 1 point transaction(s) in 'point_transactions'. Dropping this table would destroy loyalty audit history" in str(exc_info.value)

        # Assert point transaction was preserved!
        pt_count = conn.execute(sa.text("SELECT COUNT(1) FROM point_transactions")).scalar()
        assert pt_count == 1


def test_qr_scan_awards_points_for_customer_and_partner(client: TestClient, seed_data):
    admin = seed_data["admin"]
    partner = seed_data["partner"]
    customer = seed_data["customer"]
    qr1 = seed_data["qr1"]
    qr2 = seed_data["qr2"]
    h_admin = admin_headers(admin)

    # Create active rules
    client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Cust Rule",
            "category": "customer_qr_scan",
            "points_awarded": 40,
            "is_active": True,
        },
        headers=h_admin,
    )
    client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Part Rule",
            "category": "partner_qr_scan",
            "points_awarded": 80,
            "is_active": True,
        },
        headers=h_admin,
    )

    # 1. Customer scans qr1
    res_c_scan = client.post(
        "/api/v1/qr/scan",
        json={"token": qr1.token},
        headers=customer_headers(customer),
    )
    assert res_c_scan.status_code == 200
    c_res = res_c_scan.json()
    assert c_res["points_awarded"] == 40
    assert c_res["qr_token"] == qr1.token

    # 2. Partner scans qr2
    res_p_scan = client.post(
        "/api/v1/qr/scan",
        json={"token": qr2.token},
        headers=partner_headers(partner),
    )
    assert res_p_scan.status_code == 200
    p_res = res_p_scan.json()
    assert p_res["points_awarded"] == 80
    assert p_res["qr_token"] == qr2.token


def test_qr_scan_inactive_rule_rejection(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    customer = seed_data["customer"]
    batch = db_session.query(QrBatch).first()

    qr_fresh = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="C" * 32,
        code_data=f"score://qr/v1?token={'C'*32}&type=product",
        status="active",
    )
    db_session.add(qr_fresh)
    db_session.commit()

    # Create inactive rule
    client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Inactive Cust Rule",
            "category": "customer_qr_scan",
            "points_awarded": 50,
            "is_active": False,
        },
        headers=admin_headers(admin),
    )

    res = client.post(
        "/api/v1/qr/scan",
        json={"token": qr_fresh.token},
        headers=customer_headers(customer),
    )
    assert res.status_code == 400
    assert "No active loyalty point rule is currently in effect" in res.json()["detail"]


def test_qr_scan_effective_date_validation(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    customer = seed_data["customer"]
    batch = db_session.query(QrBatch).first()

    qr_future = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="D" * 32,
        code_data=f"score://qr/v1?token={'D'*32}&type=product",
        status="active",
    )
    db_session.add(qr_future)
    db_session.commit()

    # Rule effective starting tomorrow
    tomorrow = (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()
    client.post(
        "/api/v1/admin/points-rules",
        json={
            "rule_name": "Future Rule",
            "category": "customer_qr_scan",
            "points_awarded": 100,
            "effective_from": tomorrow,
            "is_active": True,
        },
        headers=admin_headers(admin),
    )

    res = client.post(
        "/api/v1/qr/scan",
        json={"token": qr_future.token},
        headers=customer_headers(customer),
    )
    assert res.status_code == 400
    assert "No active loyalty point rule is currently in effect" in res.json()["detail"]


def test_duplicate_qr_scan_prevention(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    customer = seed_data["customer"]
    partner = seed_data["partner"]
    batch = db_session.query(QrBatch).first()

    qr = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="E" * 32,
        code_data=f"score://qr/v1?token={'E'*32}&type=product",
        status="active",
    )
    db_session.add(qr)
    db_session.commit()

    client.post(
        "/api/v1/admin/points-rules",
        json={"rule_name": "Scan Rule", "category": "customer_qr_scan", "points_awarded": 25, "is_active": True},
        headers=admin_headers(admin),
    )

    # 1. First scan succeeds
    res1 = client.post("/api/v1/qr/scan", json={"token": qr.token}, headers=customer_headers(customer))
    assert res1.status_code == 200

    # 2. Repeated scan by same user is rejected (409 Conflict)
    res2 = client.post("/api/v1/qr/scan", json={"token": qr.token}, headers=customer_headers(customer))
    assert res2.status_code == 409
    assert "already been scanned and redeemed" in res2.json()["detail"]

    # 3. Repeated scan by different user is also rejected
    res3 = client.post("/api/v1/qr/scan", json={"token": qr.token}, headers=partner_headers(partner))
    assert res3.status_code == 409
    assert "already been scanned and redeemed" in res3.json()["detail"]


def test_qr_scan_idempotency_key_replay(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    customer = seed_data["customer"]
    batch = db_session.query(QrBatch).first()

    qr = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="F" * 32,
        code_data=f"score://qr/v1?token={'F'*32}&type=product",
        status="active",
    )
    db_session.add(qr)
    db_session.commit()

    client.post(
        "/api/v1/admin/points-rules",
        json={"rule_name": "Scan Rule", "category": "customer_qr_scan", "points_awarded": 35, "is_active": True},
        headers=admin_headers(admin),
    )

    idem_key = "idemp-client-key-999"
    # Initial scan with idempotency key
    res1 = client.post(
        "/api/v1/qr/scan",
        json={"token": qr.token, "idempotency_key": idem_key},
        headers=customer_headers(customer),
    )
    assert res1.status_code == 200
    assert res1.json()["is_idempotent_replay"] is False

    # Replay with same idempotency key returns idempotent success
    res2 = client.post(
        "/api/v1/qr/scan",
        json={"token": qr.token, "idempotency_key": idem_key},
        headers=customer_headers(customer),
    )
    assert res2.status_code == 200
    assert res2.json()["is_idempotent_replay"] is True
    assert res2.json()["qr_token"] == qr.token


def test_qr_scan_type_validation_and_role_authorization(client: TestClient, seed_data, db_session: Session):
    admin = seed_data["admin"]
    customer = seed_data["customer"]
    partner = seed_data["partner"]
    batch = db_session.query(QrBatch).first()

    # Create staff user for testing
    from app.core.security import hash_password, create_access_token
    staff = User(
        name="Staff User",
        mobile="9000000099",
        password_hash=hash_password("staff123"),
        role="staff",
        is_active=True,
    )
    db_session.add(staff)
    db_session.flush()

    # 1. Staff QR code scan rejection
    qr_staff = QrCode(
        batch_id=batch.id,
        qr_type="staff",
        token="STAFF_QR_" + "S" * 20,
        code_data="score://qr/v1?token=STAFF_QR_" + "S" * 20 + "&type=staff",
        status="active",
        target_user_id=staff.id,
    )
    db_session.add(qr_staff)

    # 2. Invoice QR code scan rejection
    qr_inv = QrCode(
        batch_id=batch.id,
        qr_type="invoice",
        token="INV_QR_" + "I" * 20,
        code_data="score://qr/v1?token=INV_QR_" + "I" * 20 + "&type=invoice",
        status="active",
    )
    db_session.add(qr_inv)

    # 3. Expired product QR code
    qr_exp = QrCode(
        batch_id=batch.id,
        qr_type="product",
        token="EXP_QR_" + "X" * 20,
        code_data="score://qr/v1?token=EXP_QR_" + "X" * 20 + "&type=product",
        status="active",
        expires_at=datetime(2020, 1, 1, tzinfo=timezone.utc),
    )
    db_session.add(qr_exp)
    db_session.commit()

    # Test staff QR rejected at loyalty scan endpoint
    res_staff_qr = client.post(
        "/api/v1/qr/scan",
        json={"code_data": qr_staff.code_data},
        headers=customer_headers(customer),
    )
    assert res_staff_qr.status_code == 400
    assert "Inappropriate QR code type" in res_staff_qr.json()["detail"]
    assert "staff" in res_staff_qr.json()["detail"]

    # Test invoice QR rejected at loyalty scan endpoint
    res_inv_qr = client.post(
        "/api/v1/qr/scan",
        json={"code_data": qr_inv.code_data},
        headers=partner_headers(partner),
    )
    assert res_inv_qr.status_code == 400
    assert "Inappropriate QR code type" in res_inv_qr.json()["detail"]
    assert "invoice" in res_inv_qr.json()["detail"]

    # Test staff user role cannot scan for loyalty points
    qr_valid = seed_data["qr1"]
    staff_token = create_access_token(subject=str(staff.id), role="staff", mobile=staff.mobile)
    res_staff_caller = client.post(
        "/api/v1/qr/scan",
        json={"token": qr_valid.token},
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert res_staff_caller.status_code == 403
    assert "not eligible to scan QR codes" in res_staff_caller.json()["detail"]

    # Test expired QR code
    res_expired = client.post(
        "/api/v1/qr/scan",
        json={"token": qr_exp.token},
        headers=customer_headers(customer),
    )
    assert res_expired.status_code == 400
    assert "expired" in res_expired.json()["detail"].lower()

    # Test nonexistent QR token
    res_not_found = client.post(
        "/api/v1/qr/scan",
        json={"token": "NON_EXISTENT_TOKEN_123"},
        headers=customer_headers(customer),
    )
    assert res_not_found.status_code == 404


# =============================================================================
# Feature H1: Product QR Number Printing Tests
# =============================================================================


def test_product_qr_labels_retrieval_and_preservation(client: TestClient, seed_data):
    admin = seed_data["admin"]
    p1 = seed_data["product1"]
    p2 = seed_data["product2"]
    qr1 = seed_data["qr1"]
    h = admin_headers(admin)

    # Fetch labels for p1 and p2
    res = client.post(
        "/api/v1/admin/qr/products/labels",
        json={"product_ids": [p1.id, p2.id]},
        headers=h,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 2
    item1 = next(it for it in data["items"] if it["product_id"] == p1.id)
    # Existing QR number must be preserved
    assert item1["qr_number"] == qr1.token
    assert item1["product_name"] == p1.name
    assert item1["product_code"] == p1.product_code

    # Calling again must preserve the exact same QR numbers
    res2 = client.post(
        "/api/v1/admin/qr/products/labels",
        json={"product_ids": [p1.id, p2.id]},
        headers=h,
    )
    assert res2.json() == data


def test_product_qr_labels_pdf_download(client: TestClient, seed_data):
    admin = seed_data["admin"]
    p1 = seed_data["product1"]
    p2 = seed_data["product2"]
    h = admin_headers(admin)

    # 1. POST PDF
    res_post = client.post(
        "/api/v1/admin/qr/products/labels/pdf",
        json={"product_ids": [p1.id, p2.id]},
        headers=h,
    )
    assert res_post.status_code == 200
    assert res_post.headers["content-type"] == "application/pdf"
    assert res_post.content.startswith(b"%PDF-")

    # 2. GET PDF query params
    res_get = client.get(
        f"/api/v1/admin/qr/products/labels/pdf?product_ids={p1.id},{p2.id}",
        headers=h,
    )
    assert res_get.status_code == 200
    assert res_get.headers["content-type"] == "application/pdf"
    assert res_get.content.startswith(b"%PDF-")


# =============================================================================
# Feature H2: Partner-Specific Percentage Discounts Tests
# =============================================================================


def test_partner_account_creation_with_discount(client: TestClient, seed_data):
    admin = seed_data["admin"]
    h = admin_headers(admin)

    # Valid partner creation with discount
    payload = {
        "name": "Discounted Partner",
        "mobile": "9111222333",
        "password": "partnerPassword123",
        "business_name": "Discount Hub",
        "business_address": "456 Market St",
        "partner_code": "PRT-DISC",
        "discount_percentage": "15.50",
    }
    res = client.post("/api/v1/admin/users/partners", json=payload, headers=h)
    assert res.status_code == 201
    data = res.json()
    assert float(data["partner_profile"]["discount_percentage"]) == 15.50

    # Validation: reject negative discount
    payload["mobile"] = "9111222334"
    payload["partner_code"] = "PRT-DISC2"
    payload["discount_percentage"] = "-5.00"
    res_neg = client.post("/api/v1/admin/users/partners", json=payload, headers=h)
    assert res_neg.status_code == 422

    # Validation: reject discount > 100%
    payload["discount_percentage"] = "105.00"
    res_high = client.post("/api/v1/admin/users/partners", json=payload, headers=h)
    assert res_high.status_code == 422


def test_admin_update_partner_discount(client: TestClient, seed_data):
    admin = seed_data["admin"]
    partner = seed_data["partner"]
    h = admin_headers(admin)

    res = client.patch(
        f"/api/v1/admin/users/{partner.id}",
        json={"discount_percentage": "25.00"},
        headers=h,
    )
    assert res.status_code == 200
    data = res.json()
    assert float(data["partner_profile"]["discount_percentage"]) == 25.00


def test_partner_order_discount_calculation_and_snapshots(client: TestClient, seed_data):
    partner = seed_data["partner"]
    p1 = seed_data["product1"]  # Price = 1000.00
    h = partner_headers(partner)  # Partner has 10.00% discount configured

    # 1. Preview order
    preview_res = client.post(
        "/api/v1/orders/preview",
        json={"items": [{"product_id": p1.id, "quantity": 2}]},
        headers=h,
    )
    assert preview_res.status_code == 200
    prev = preview_res.json()
    assert float(prev["subtotal_before_discount"]) == 2000.00
    assert float(prev["discount_percentage"]) == 10.00
    assert float(prev["total_discount"]) == 200.00
    assert float(prev["final_total"]) == 1800.00
    assert float(prev["grand_total"]) == 1800.00
    item_prev = prev["items"][0]
    assert float(item_prev["original_price"]) == 1000.00
    assert float(item_prev["discount_amount"]) == 100.00
    assert float(item_prev["discounted_price"]) == 900.00
    assert float(item_prev["subtotal"]) == 1800.00

    # 2. Place order
    order_res = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p1.id, "quantity": 2}]},
        headers=h,
    )
    assert order_res.status_code == 201
    order = order_res.json()
    assert float(order["subtotal_before_discount"]) == 2000.00
    assert float(order["discount_percentage"]) == 10.00
    assert float(order["total_discount"]) == 200.00
    assert float(order["final_total"]) == 1800.00
    assert float(order["order_total"]) == 1800.00
    item_order = order["items"][0]
    assert float(item_order["original_price"]) == 1000.00
    assert float(item_order["discount_amount"]) == 100.00
    assert float(item_order["discounted_price"]) == 900.00


def test_historical_order_preservation_on_partner_or_price_update(
    client: TestClient, seed_data, db_session: Session
):
    admin = seed_data["admin"]
    partner = seed_data["partner"]
    p1 = seed_data["product1"]  # 1000.00
    h_partner = partner_headers(partner)  # 10%
    h_admin = admin_headers(admin)

    # Place order with 10% discount
    res = client.post(
        "/api/v1/orders",
        json={"items": [{"product_id": p1.id, "quantity": 1}]},
        headers=h_partner,
    )
    order_id = res.json()["id"]

    # Admin changes partner discount to 50%
    client.patch(
        f"/api/v1/admin/users/{partner.id}",
        json={"discount_percentage": "50.00"},
        headers=h_admin,
    )

    # Admin changes product price to 2000.00
    client.patch(
        f"/api/v1/admin/catalogue/products/{p1.id}",
        json={"price": "2000.00"},
        headers=h_admin,
    )

    # Fetch the previously placed order (via partner GET and admin GET)
    hist_order_res = client.get(f"/api/v1/orders/{order_id}", headers=h_partner)
    assert hist_order_res.status_code == 200
    hist_order = hist_order_res.json()

    # Historical values must remain completely intact!
    assert float(hist_order["subtotal_before_discount"]) == 1000.00
    assert float(hist_order["discount_percentage"]) == 10.00
    assert float(hist_order["total_discount"]) == 100.00
    assert float(hist_order["final_total"]) == 900.00
    assert float(hist_order["order_total"]) == 900.00
    assert float(hist_order["items"][0]["original_price"]) == 1000.00
    assert float(hist_order["items"][0]["discounted_price"]) == 900.00

    # Invoice PDF also renders without error and reflects the snapshot
    pdf_bytes = client.get(f"/api/v1/orders/{order_id}/pdf", headers=h_partner).content
    assert pdf_bytes.startswith(b"%PDF-")
