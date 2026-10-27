from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timezone
from decimal import Decimal
import io
from typing import Any

import openpyxl
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
            ProductCategory.__table__,
            Product.__table__,
            PointsRule.__table__,
            QrBatch.__table__,
            QrCode.__table__,
        ],
    )

    def override_get_db() -> Generator[Session, None, None]:
        with Session(engine, expire_on_commit=False) as db:
            yield db

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides = previous_overrides


@pytest.fixture
def db_session(client: TestClient) -> Generator[Session, None, None]:
    override = app.dependency_overrides[get_db]
    session_gen = override()
    session = next(session_gen)
    try:
        yield session
    finally:
        session.close()


def create_test_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
    is_active: bool = True,
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password("Score@Admin123"),
        role=role,
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    if role == "partner":
        profile = PartnerProfile(
            user_id=user.id,
            business_name=f"{name} Workshop",
            business_address="123 Industrial Estate, Pune",
            partner_code=f"PART-{user.id:04d}",
        )
        db.add(profile)
        db.commit()
    elif role == "staff":
        profile = StaffProfile(
            user_id=user.id,
            staff_id=f"EMP-{user.id:04d}",
        )
        db.add(profile)
        db.commit()
    elif role == "customer":
        profile = CustomerProfile(
            user_id=user.id,
            city="Pune",
            state="Maharashtra",
        )
        db.add(profile)
        db.commit()

    return user


def create_test_product(db: Session, name: str = "Clutch Plate Pro", code: str = "CP-9901") -> Product:
    category = ProductCategory(name="Clutch Parts", description="Clutch assemblies", is_active=True)
    db.add(category)
    db.commit()
    db.refresh(category)

    product = Product(
        name=name,
        product_code=code,
        category_id=category.id,
        vehicle_type="2-Wheeler",
        price=Decimal("450.00"),
        is_active=True,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def create_test_points_rule(db: Session, name: str = "Standard Product Scan", category: str = "product_qr_scan", points: int = 50) -> PointsRule:
    rule = PointsRule(
        rule_name=name,
        category=category,
        points_awarded=points,
        is_active=True,
    )
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


def auth_header(user: User) -> dict[str, str]:
    token = create_access_token(str(user.id), user.role, user.mobile)
    return {"Authorization": f"Bearer {token}"}


# -----------------------------------------------------------------------------
# Tests
# -----------------------------------------------------------------------------


def test_admin_qr_requires_admin_authorization(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9800000001", role="admin")
    customer = create_test_user(db_session, name="Customer", mobile="9800000002", role="customer")
    partner = create_test_user(db_session, name="Partner", mobile="9800000003", role="partner")
    staff = create_test_user(db_session, name="Staff", mobile="9800000004", role="staff")
    inactive_admin = create_test_user(db_session, name="Inactive Admin", mobile="9800000005", role="admin", is_active=False)

    # 1. Unauthenticated -> 401
    resp = client.get("/api/v1/admin/qr/batches")
    assert resp.status_code == 401

    # 2. Customer -> 403
    resp = client.get("/api/v1/admin/qr/batches", headers=auth_header(customer))
    assert resp.status_code == 403

    # 3. Partner -> 403
    resp = client.get("/api/v1/admin/qr/batches", headers=auth_header(partner))
    assert resp.status_code == 403

    # 4. Staff -> 403
    resp = client.get("/api/v1/admin/qr/batches", headers=auth_header(staff))
    assert resp.status_code == 403

    # 5. Inactive Admin -> 403
    resp = client.get("/api/v1/admin/qr/batches", headers=auth_header(inactive_admin))
    assert resp.status_code == 403

    # 6. Active Admin -> 200
    resp = client.get("/api/v1/admin/qr/batches", headers=auth_header(admin))
    assert resp.status_code == 200


def test_create_product_qr_batch_success(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9810000001", role="admin")
    product = create_test_product(db_session, name="Brake Shoe Set", code="BS-101")
    rule = create_test_points_rule(db_session, name="Brake Shoe Reward", points=75)

    payload = {
        "qr_type": "product",
        "quantity": 10,
        "description": "Initial manufacturing run for Brake Shoes",
        "product_id": product.id,
        "points_rule_id": rule.id,
    }

    resp = client.post("/api/v1/admin/qr/batches", json=payload, headers=auth_header(admin))
    assert resp.status_code == 201
    data = resp.json()

    assert data["qr_type"] == "product"
    assert data["quantity"] == 10
    assert data["product_id"] == product.id
    assert data["product_name"] == "Brake Shoe Set"
    assert data["points_rule_id"] == rule.id
    assert data["points_rule_name"] == "Brake Shoe Reward"
    assert data["status"] == "completed"
    assert data["active_count"] == 10
    assert data["batch_number"].startswith("BATCH-")

    # Verify codes inside batch
    batch_id = data["id"]
    codes_resp = client.get(f"/api/v1/admin/qr/batches/{batch_id}/codes", headers=auth_header(admin))
    assert codes_resp.status_code == 200
    codes_data = codes_resp.json()

    assert codes_data["total"] == 10
    assert len(codes_data["items"]) == 10

    sample = codes_data["items"][0]
    assert sample["qr_type"] == "product"
    assert sample["status"] == "active"
    assert sample["points_awarded"] == 75
    assert sample["product_id"] == product.id
    assert sample["code_data"].startswith("score://qr/v1?token=")
    assert len(sample["token"]) == 32


def test_create_batch_validation_rules(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9820000001", role="admin")
    partner = create_test_user(db_session, name="Partner", mobile="9820000002", role="partner")
    staff = create_test_user(db_session, name="Staff", mobile="9820000003", role="staff")

    # 1. Product QR requires product_id
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "product", "quantity": 5},
        headers=auth_header(admin),
    )
    assert resp.status_code == 422

    # 2. Non-existent product_id -> 404
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "product", "product_id": 99999, "quantity": 5},
        headers=auth_header(admin),
    )
    assert resp.status_code == 404

    # 3. Partner QR with non-partner user -> 400
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "partner", "target_user_id": staff.id, "quantity": 5},
        headers=auth_header(admin),
    )
    assert resp.status_code == 400
    assert "partner" in resp.json()["detail"]

    # 4. Quantity out of bounds
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 0},
        headers=auth_header(admin),
    )
    assert resp.status_code == 422

    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 1001},
        headers=auth_header(admin),
    )
    assert resp.status_code == 422


def test_create_invoice_partner_staff_batches(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9830000001", role="admin")
    partner = create_test_user(db_session, name="Partner", mobile="9830000002", role="partner")
    staff = create_test_user(db_session, name="Staff", mobile="9830000003", role="staff")

    # Invoice batch
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 5, "description": "October Invoices"},
        headers=auth_header(admin),
    )
    assert resp.status_code == 201
    assert resp.json()["qr_type"] == "invoice"

    # Partner batch
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "partner", "quantity": 2, "target_user_id": partner.id},
        headers=auth_header(admin),
    )
    assert resp.status_code == 201
    assert resp.json()["target_user_name"] == "Partner"

    # Staff batch
    resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "staff", "quantity": 1, "target_user_id": staff.id},
        headers=auth_header(admin),
    )
    assert resp.status_code == 201
    assert resp.json()["target_user_name"] == "Staff"


def test_export_batch_excel_success(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9840000001", role="admin")
    product = create_test_product(db_session, name="Speedometer Cable", code="SC-502")
    rule = create_test_points_rule(db_session, name="Cable Points", points=30)

    # Create batch of 3 codes
    create_resp = client.post(
        "/api/v1/admin/qr/batches",
        json={
            "qr_type": "product",
            "quantity": 3,
            "product_id": product.id,
            "points_rule_id": rule.id,
            "description": "Batch for export test",
        },
        headers=auth_header(admin),
    )
    assert create_resp.status_code == 201
    batch_id = create_resp.json()["id"]
    batch_number = create_resp.json()["batch_number"]

    # Request Excel Export
    resp = client.get(
        f"/api/v1/admin/qr/batches/{batch_id}/export/excel",
        headers=auth_header(admin),
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    assert f'filename="{batch_number}_qr_codes.xlsx"' in resp.headers["content-disposition"]

    # Verify Excel workbook content using openpyxl
    wb = openpyxl.load_workbook(io.BytesIO(resp.content))
    assert "QR Codes" in wb.sheetnames
    ws = wb["QR Codes"]

    # Verify header
    headers = [cell.value for cell in ws[1]]
    assert "Batch ID" in headers
    assert "Batch Number" in headers
    assert "QR ID" in headers
    assert "QR Token" in headers
    assert "QR Code Data (Payload)" in headers
    assert "QR Type" in headers
    assert "Points Awarded" in headers
    assert "Status" in headers

    # Verify rows (1 header + 3 data rows = 4 rows)
    assert ws.max_row == 4
    column = {header: index + 1 for index, header in enumerate(headers)}
    for r in range(2, 5):
        assert ws.cell(row=r, column=column["Batch ID"]).value == batch_id
        assert ws.cell(row=r, column=column["Batch Number"]).value == batch_number
        assert len(str(ws.cell(row=r, column=column["QR Token"]).value)) == 32
        assert "score://qr/v1?token=" in str(
            ws.cell(row=r, column=column["QR Code Data (Payload)"]).value
        )
        assert ws.cell(row=r, column=column["QR Type"]).value == "PRODUCT"
        assert ws.cell(row=r, column=column["Points Awarded"]).value == 30
        assert ws.cell(row=r, column=column["Status"]).value == "ACTIVE"


def test_export_batch_csv_success(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9850000001", role="admin")

    create_resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 2},
        headers=auth_header(admin),
    )
    batch_id = create_resp.json()["id"]

    resp = client.get(
        f"/api/v1/admin/qr/batches/{batch_id}/export/csv",
        headers=auth_header(admin),
    )
    assert resp.status_code == 200
    assert "text/csv" in resp.headers["content-type"]
    text = resp.text
    assert "Batch Number,QR Token" in text
    lines = text.strip().splitlines()
    assert len(lines) == 3  # 1 header + 2 items


def test_update_qr_code_status(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9860000001", role="admin")

    create_resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 1},
        headers=auth_header(admin),
    )
    batch_id = create_resp.json()["id"]

    codes_resp = client.get(f"/api/v1/admin/qr/batches/{batch_id}/codes", headers=auth_header(admin))
    code_id = codes_resp.json()["items"][0]["id"]
    assert codes_resp.json()["items"][0]["status"] == "active"

    # Void the code
    patch_resp = client.patch(
        f"/api/v1/admin/qr/codes/{code_id}/status",
        json={"status": "voided"},
        headers=auth_header(admin),
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["status"] == "voided"

    # Reactivate the code
    patch_resp = client.patch(
        f"/api/v1/admin/qr/codes/{code_id}/status",
        json={"status": "active"},
        headers=auth_header(admin),
    )
    assert patch_resp.status_code == 200
    assert patch_resp.json()["status"] == "active"


def test_list_batches_filters_and_search(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9870000001", role="admin")

    client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 1, "description": "Filter Search Match"},
        headers=auth_header(admin),
    )
    client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "staff", "quantity": 1, "description": "Other Unrelated"},
        headers=auth_header(admin),
    )

    # Filter by qr_type
    resp = client.get("/api/v1/admin/qr/batches?qr_type=invoice", headers=auth_header(admin))
    assert resp.status_code == 200
    assert resp.json()["total"] == 1
    assert resp.json()["items"][0]["qr_type"] == "invoice"

    # Search by description
    resp = client.get("/api/v1/admin/qr/batches?search=Match", headers=auth_header(admin))
    assert resp.status_code == 200
    assert resp.json()["total"] == 1
    assert resp.json()["items"][0]["description"] == "Filter Search Match"


def test_get_qr_batch_detail_and_not_found(client: TestClient, db_session: Session) -> None:
    admin = create_test_user(db_session, name="Admin", mobile="9880000001", role="admin")

    create_resp = client.post(
        "/api/v1/admin/qr/batches",
        json={"qr_type": "invoice", "quantity": 2, "description": "Detail Test"},
        headers=auth_header(admin),
    )
    batch_id = create_resp.json()["id"]

    resp = client.get(f"/api/v1/admin/qr/batches/{batch_id}", headers=auth_header(admin))
    assert resp.status_code == 200
    assert resp.json()["id"] == batch_id
    assert resp.json()["description"] == "Detail Test"

    # Not found
    resp = client.get("/api/v1/admin/qr/batches/99999", headers=auth_header(admin))
    assert resp.status_code == 404
