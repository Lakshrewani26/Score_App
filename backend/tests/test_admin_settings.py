from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timezone
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
    PartnerProfile,
    PointsRule,
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
def client() -> Generator[TestClient, None, None]:
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
            PointsRule.__table__,
        ],
    )

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine, expire_on_commit=False) as db:
            yield db

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)
    engine.dispose()


@pytest.fixture
def seed_users(client: TestClient) -> dict[str, Any]:
    with next(app.dependency_overrides[get_db]()) as session:
        admin = User(
            name="Super Admin",
            mobile="9876543210",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=True,
        )
        session.add(admin)

        deactivated_admin = User(
            name="Deactivated Admin",
            mobile="9876543219",
            password_hash=hash_password("adminSecret123"),
            role="admin",
            is_active=False,
        )
        session.add(deactivated_admin)

        customer = User(
            name="Ravi Kumar",
            mobile="9876543211",
            password_hash=hash_password("custSecret123"),
            role="customer",
            is_active=True,
        )
        session.add(customer)

        partner = User(
            name="Rajesh Auto",
            mobile="9876543212",
            password_hash=hash_password("partSecret123"),
            role="partner",
            is_active=True,
        )
        session.add(partner)

        staff = User(
            name="Vikram Staff",
            mobile="9876543213",
            password_hash=hash_password("staffSecret123"),
            role="staff",
            is_active=True,
        )
        session.add(staff)
        session.commit()

        return {
            "admin": admin,
            "deactivated_admin": deactivated_admin,
            "customer": customer,
            "partner": partner,
            "staff": staff,
            "admin_token": create_access_token(str(admin.id), "admin", admin.mobile),
            "deactivated_admin_token": create_access_token(
                str(deactivated_admin.id), "admin", deactivated_admin.mobile
            ),
            "customer_token": create_access_token(
                str(customer.id), "customer", customer.mobile
            ),
            "partner_token": create_access_token(
                str(partner.id), "partner", partner.mobile
            ),
            "staff_token": create_access_token(str(staff.id), "staff", staff.mobile),
        }


# =============================================================================
# System Information Tests
# =============================================================================


def test_system_info_requires_admin_auth(client: TestClient, seed_users: dict[str, Any]) -> None:
    # 1. Unauthenticated request
    resp = client.get("/api/v1/admin/settings/system-info")
    assert resp.status_code == 401

    # 2. Non-admin roles
    for role_key in ["customer_token", "partner_token", "staff_token"]:
        token = seed_users[role_key]
        resp = client.get(
            "/api/v1/admin/settings/system-info",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 403

    # 3. Deactivated admin
    resp = client.get(
        "/api/v1/admin/settings/system-info",
        headers={"Authorization": f"Bearer {seed_users['deactivated_admin_token']}"},
    )
    assert resp.status_code == 403


def test_system_info_success_and_excludes_secrets(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]
    resp = client.get(
        "/api/v1/admin/settings/system-info",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    data = resp.json()

    assert data["app_name"] == "Score API"
    assert data["environment"] in ["development", "production", "test"]
    assert "Phase 7" in data["api_version"]
    assert data["database_status"] in ["connected", "degraded"]

    # Verify alias endpoint /settings behaves identically
    alias_resp = client.get(
        "/api/v1/admin/settings",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert alias_resp.status_code == 200
    assert alias_resp.json() == data

    # Verify no secrets or deployment credentials are leaked in response
    resp_text = resp.text.lower()
    assert "jwt_secret_key" not in resp_text
    assert "database_url" not in resp_text
    assert "password" not in resp_text
    assert TEST_SECRET_KEY.lower() not in resp_text


# =============================================================================
# Points System Rules Tests
# =============================================================================


def test_points_rules_authorization_enforcement(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    endpoints = [
        ("GET", "/api/v1/admin/points-rules"),
        ("POST", "/api/v1/admin/points-rules"),
        ("GET", "/api/v1/admin/points-rules/1"),
        ("PATCH", "/api/v1/admin/points-rules/1"),
        ("POST", "/api/v1/admin/points-rules/1/status"),
    ]

    for method, path in endpoints:
        # Unauthenticated
        resp = client.request(method, path, json={"is_active": True})
        assert resp.status_code == 401

        # Non-admin roles
        for role_key in ["customer_token", "partner_token", "staff_token"]:
            token = seed_users[role_key]
            resp = client.request(
                method, path, headers={"Authorization": f"Bearer {token}"}, json={"is_active": True}
            )
            assert resp.status_code == 403

        # Deactivated Admin
        resp = client.request(
            method,
            path,
            headers={"Authorization": f"Bearer {seed_users['deactivated_admin_token']}"},
            json={"is_active": True},
        )
        assert resp.status_code == 403


def test_create_points_rule_success(client: TestClient, seed_users: dict[str, Any]) -> None:
    token = seed_users["admin_token"]
    payload = {
        "rule_name": "Standard Customer Scan Award",
        "rule_description": "Grants 50 loyalty points per verified 2-Wheeler packaging scan.",
        "category": "product_qr_scan",
        "points_awarded": 50,
        "points_required": None,
        "min_transaction_value": None,
        "max_transaction_value": None,
        "effective_from": "2026-01-01T00:00:00Z",
        "effective_to": "2026-12-31T23:59:59Z",
        "is_active": True,
    }

    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json=payload,
    )
    assert resp.status_code == 201
    data = resp.json()

    assert data["id"] > 0
    assert data["rule_name"] == "Standard Customer Scan Award"
    assert data["rule_description"] == payload["rule_description"]
    assert data["category"] == "product_qr_scan"
    assert data["points_awarded"] == 50
    assert data["points_required"] is None
    assert data["is_active"] is True
    assert data["created_by"] == seed_users["admin"].id
    assert data["created_by_name"] == "Super Admin"
    assert data["updated_by_name"] == "Super Admin"
    assert data["created_at"] is not None


def test_list_points_rules_filters_and_search(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]

    # Create 3 rules
    rules_payload = [
        {
            "rule_name": "Product Scan Tier 1",
            "rule_description": "Points on scanning genuine parts",
            "category": "product_qr_scan",
            "points_awarded": 25,
            "is_active": True,
        },
        {
            "rule_name": "Invoice QR Partner Tier 2",
            "rule_description": "Dealer wholesale invoice scanning rewards",
            "category": "invoice_qr_scan",
            "points_awarded": 150,
            "min_transaction_value": "5000.00",
            "is_active": True,
        },
        {
            "rule_name": "Legacy Points Redemption Discount",
            "rule_description": "Redeem points for catalog goods discount",
            "category": "redemption",
            "points_required": 500,
            "is_active": False,
        },
    ]

    for p in rules_payload:
        resp = client.post(
            "/api/v1/admin/points-rules",
            headers={"Authorization": f"Bearer {token}"},
            json=p,
        )
        assert resp.status_code == 201

    # 1. List all rules
    resp = client.get(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    all_data = resp.json()
    assert all_data["total"] == 3
    assert len(all_data["items"]) == 3

    # 2. Filter by category
    resp_cat = client.get(
        "/api/v1/admin/points-rules?category=invoice_qr_scan",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp_cat.status_code == 200
    cat_data = resp_cat.json()
    assert cat_data["total"] == 1
    assert cat_data["items"][0]["category"] == "invoice_qr_scan"

    # 3. Filter by active status
    resp_active = client.get(
        "/api/v1/admin/points-rules?is_active=false",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp_active.status_code == 200
    active_data = resp_active.json()
    assert active_data["total"] == 1
    assert active_data["items"][0]["is_active"] is False

    # 4. Search query
    resp_search = client.get(
        "/api/v1/admin/points-rules?search=wholesale",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp_search.status_code == 200
    search_data = resp_search.json()
    assert search_data["total"] == 1
    assert "wholesale" in search_data["items"][0]["rule_description"].lower()


def test_get_points_rule_detail_and_not_found(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]

    create_resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Partner to Staff Transfer Cap",
            "category": "partner_to_staff_transfer",
            "points_awarded": 100,
            "is_active": True,
        },
    )
    assert create_resp.status_code == 201
    rule_id = create_resp.json()["id"]

    # Retrieve existing
    get_resp = client.get(
        f"/api/v1/admin/points-rules/{rule_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_resp.status_code == 200
    assert get_resp.json()["id"] == rule_id
    assert get_resp.json()["rule_name"] == "Partner to Staff Transfer Cap"

    # Retrieve non-existing
    missing_resp = client.get(
        "/api/v1/admin/points-rules/9999",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert missing_resp.status_code == 404
    assert "not found" in missing_resp.json()["detail"].lower()


def test_update_points_rule_success_and_preserves_untouched_fields(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]

    create_resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Customer to Partner Initial Rule",
            "rule_description": "Initial description",
            "category": "customer_to_partner_transfer",
            "points_awarded": 200,
            "min_transaction_value": "100.00",
            "max_transaction_value": "5000.00",
            "is_active": True,
        },
    )
    assert create_resp.status_code == 201
    rule_id = create_resp.json()["id"]

    # 1. Update with PATCH
    update_payload = {
        "rule_name": "Customer to Partner Updated Rule",
        "points_awarded": 300,
    }
    patch_resp = client.patch(
        f"/api/v1/admin/points-rules/{rule_id}",
        headers={"Authorization": f"Bearer {token}"},
        json=update_payload,
    )
    assert patch_resp.status_code == 200
    patch_data = patch_resp.json()

    assert patch_data["rule_name"] == "Customer to Partner Updated Rule"
    assert patch_data["points_awarded"] == 300
    # Untouched fields remain intact
    assert patch_data["rule_description"] == "Initial description"
    assert patch_data["category"] == "customer_to_partner_transfer"
    assert Decimal(str(patch_data["min_transaction_value"])) == Decimal("100.00")
    assert Decimal(str(patch_data["max_transaction_value"])) == Decimal("5000.00")
    assert patch_data["is_active"] is True

    # 2. Update with POST fallback /update
    post_update_resp = client.post(
        f"/api/v1/admin/points-rules/{rule_id}/update",
        headers={"Authorization": f"Bearer {token}"},
        json={"rule_description": "Updated via POST endpoint"},
    )
    assert post_update_resp.status_code == 200
    assert post_update_resp.json()["rule_description"] == "Updated via POST endpoint"


def test_update_points_rule_status_toggle(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]

    create_resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Status Toggle Target Rule",
            "category": "redemption",
            "points_required": 100,
            "is_active": True,
        },
    )
    rule_id = create_resp.json()["id"]

    # 1. Deactivate via POST
    deactivate_resp = client.post(
        f"/api/v1/admin/points-rules/{rule_id}/status",
        headers={"Authorization": f"Bearer {token}"},
        json={"is_active": False},
    )
    assert deactivate_resp.status_code == 200
    assert deactivate_resp.json()["is_active"] is False

    # 2. Reactivate via PATCH
    reactivate_resp = client.patch(
        f"/api/v1/admin/points-rules/{rule_id}/status",
        headers={"Authorization": f"Bearer {token}"},
        json={"is_active": True},
    )
    assert reactivate_resp.status_code == 200
    assert reactivate_resp.json()["is_active"] is True


def test_points_rule_validations(client: TestClient, seed_users: dict[str, Any]) -> None:
    token = seed_users["admin_token"]

    # 1. Empty or whitespace-only rule name
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={"rule_name": "   ", "category": "product_qr_scan"},
    )
    assert resp.status_code == 422

    # 2. Unsupported category
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={"rule_name": "Invalid Category Rule", "category": "crypto_cashback"},
    )
    assert resp.status_code == 422

    # 3. Negative points awarded
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={"rule_name": "Negative Points", "category": "product_qr_scan", "points_awarded": -10},
    )
    assert resp.status_code == 422

    # 4. Negative points required
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={"rule_name": "Negative Required", "category": "redemption", "points_required": -50},
    )
    assert resp.status_code == 422

    # 5. Negative min transaction value
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Negative Min Val",
            "category": "product_qr_scan",
            "min_transaction_value": -100,
        },
    )
    assert resp.status_code == 422

    # 6. min_transaction_value > max_transaction_value
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Min Exceeds Max",
            "category": "invoice_qr_scan",
            "min_transaction_value": 5000,
            "max_transaction_value": 1000,
        },
    )
    assert resp.status_code == 422

    # 7. effective_from > effective_to
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Date Inversion",
            "category": "product_qr_scan",
            "effective_from": "2026-12-31T00:00:00Z",
            "effective_to": "2026-01-01T00:00:00Z",
        },
    )
    assert resp.status_code == 422

    # 8. Extra / unknown fields rejected (extra="forbid")
    resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Extra Field Rule",
            "category": "product_qr_scan",
            "unsupported_extra_field": "injected_value",
        },
    )
    assert resp.status_code == 422


def test_cross_field_validation_on_update_with_merged_values(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]

    create_resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Merge Boundary Rule",
            "category": "invoice_qr_scan",
            "min_transaction_value": "1000.00",
            "max_transaction_value": "5000.00",
            "effective_from": "2026-06-01T00:00:00Z",
            "effective_to": "2026-12-01T00:00:00Z",
        },
    )
    rule_id = create_resp.json()["id"]

    # Updating max to less than existing min (500 < 1000)
    resp_invalid_max = client.patch(
        f"/api/v1/admin/points-rules/{rule_id}",
        headers={"Authorization": f"Bearer {token}"},
        json={"max_transaction_value": "500.00"},
    )
    assert resp_invalid_max.status_code == 400
    assert "minimum transaction value cannot exceed" in resp_invalid_max.json()["detail"].lower()

    # Updating start date to after existing end date
    resp_invalid_start = client.patch(
        f"/api/v1/admin/points-rules/{rule_id}",
        headers={"Authorization": f"Bearer {token}"},
        json={"effective_from": "2026-12-31T00:00:00Z"},
    )
    assert resp_invalid_start.status_code == 400
    assert "effective start date cannot be after" in resp_invalid_start.json()["detail"].lower()


def test_no_hard_deletion_of_rules_allowed(
    client: TestClient, seed_users: dict[str, Any]
) -> None:
    token = seed_users["admin_token"]

    create_resp = client.post(
        "/api/v1/admin/points-rules",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "rule_name": "Permanent Historical Rule",
            "category": "product_qr_scan",
            "points_awarded": 10,
        },
    )
    rule_id = create_resp.json()["id"]

    # DELETE is not allowed; must return 405 Method Not Allowed
    del_resp = client.delete(
        f"/api/v1/admin/points-rules/{rule_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert del_resp.status_code == 405

    # Verify rule still exists
    get_resp = client.get(
        f"/api/v1/admin/points-rules/{rule_id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert get_resp.status_code == 200
    assert get_resp.json()["rule_name"] == "Permanent Historical Rule"
