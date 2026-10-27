from __future__ import annotations

from collections.abc import Generator
from decimal import Decimal
from unittest.mock import MagicMock, patch

import httpx
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

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
    Product,
    ProductCategory,
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
            ProductCategory.__table__,
            Product.__table__,
            Order.__table__,
            OrderItem.__table__,
            OrderStatusHistory.__table__,
        ],
    )
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine) -> Generator[Session, None, None]:
    with Session(test_engine, expire_on_commit=False) as session:
        yield session


@pytest.fixture
def client(test_engine) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        with Session(test_engine, expire_on_commit=False) as session:
            yield session

    previous_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous_overrides)



def _create_partner(db: Session, mobile: str = "9876543210", name: str = "Rahul Partner") -> tuple[User, str]:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password("PartnerSecret123"),
        role="partner",
        is_active=True,
    )
    db.add(user)
    db.flush()

    profile = PartnerProfile(
        user_id=user.id,
        business_name="Rahul Auto Spares",
        business_address="Shop 10, GT Road, Delhi",
        partner_code=f"RP-{user.id:04d}",
    )
    db.add(profile)
    db.commit()
    db.refresh(user)

    token = create_access_token(subject=str(user.id), role="partner", mobile=user.mobile)
    return user, token


def _create_products(db: Session) -> tuple[Product, Product, Product]:
    category = ProductCategory(name="Engine Components", description="Engine parts")
    db.add(category)
    db.flush()

    p1 = Product(
        category_id=category.id,
        product_code="TYRE-001",
        name="Tubeless Radial Tyre",
        vehicle_type="2-Wheeler",
        price=Decimal("1500.00"),
        is_active=True,
    )
    p2 = Product(
        category_id=category.id,
        product_code="BRAKE-002",
        name="Front Brake Shoe Set",
        vehicle_type="2-Wheeler",
        price=Decimal("350.50"),
        is_active=True,
    )
    # Product without a configured price (null price)
    p3 = Product(
        category_id=category.id,
        product_code="CLUTCH-003",
        name="Custom Clutch Assembly",
        vehicle_type="3-Wheeler",
        price=None,
        is_active=True,
    )
    db.add_all([p1, p2, p3])
    db.commit()
    db.refresh(p1)
    db.refresh(p2)
    db.refresh(p3)
    return p1, p2, p3


def test_partner_order_preview_success(client: TestClient, db_session: Session) -> None:
    _, token = _create_partner(db_session, mobile="9800000001")
    p1, p2, _ = _create_products(db_session)

    response = client.post(
        "/api/v1/orders/preview",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "items": [
                {"product_id": p1.id, "quantity": 2},
                {"product_id": p2.id, "quantity": 3},
            ]
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["item_count"] == 2
    assert data["total_quantity"] == 5
    # (2 * 1500.00) + (3 * 350.50) = 3000 + 1051.50 = 4051.50
    assert Decimal(str(data["grand_total"])) == Decimal("4051.50")
    assert data["items"][0]["product_code"] == "TYRE-001"
    assert Decimal(str(data["items"][0]["subtotal"])) == Decimal("3000.00")


def test_partner_order_preview_rejects_null_price(client: TestClient, db_session: Session) -> None:
    _, token = _create_partner(db_session, mobile="9800000002")
    p1, _, p3 = _create_products(db_session)

    response = client.post(
        "/api/v1/orders/preview",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "items": [
                {"product_id": p1.id, "quantity": 1},
                {"product_id": p3.id, "quantity": 1},  # Has null price
            ]
        },
    )

    assert response.status_code == 422
    assert "does not have an authorized price" in response.json()["detail"]


def test_partner_order_creation_success(client: TestClient, db_session: Session) -> None:
    partner, token = _create_partner(db_session, mobile="9800000003")
    p1, p2, _ = _create_products(db_session)

    response = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "items": [
                {"product_id": p1.id, "quantity": 2},
                {"product_id": p2.id, "quantity": 1},
            ],
            "notes": "Urgent delivery required",
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "pending_approval"
    assert data["partner_id"] == partner.id
    assert data["partner_name"] == partner.name
    assert data["business_name"] == "Rahul Auto Spares"
    assert data["item_count"] == 2
    assert data["total_quantity"] == 3
    # 2 * 1500 + 1 * 350.50 = 3350.50
    assert Decimal(str(data["order_total"])) == Decimal("3350.50")
    assert "Urgent delivery required" in data["notes"]
    assert data["order_number"].startswith("ORD-")

    # Verify items snapshots in database
    db_order = db_session.get(Order, data["id"])
    assert db_order is not None
    assert db_order.status == "pending_approval"
    assert len(db_order.items) == 2
    assert db_order.items[0].unit_price == Decimal("1500.00")


def test_partner_order_creation_rejects_empty_cart(client: TestClient, db_session: Session) -> None:
    _, token = _create_partner(db_session, mobile="9800000004")

    response = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json={"items": []},
    )
    assert response.status_code == 422


def test_partner_order_creation_rejects_negative_or_zero_quantity(
    client: TestClient, db_session: Session
) -> None:
    _, token = _create_partner(db_session, mobile="9800000005")
    p1, _, _ = _create_products(db_session)

    response = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json={"items": [{"product_id": p1.id, "quantity": 0}]},
    )
    assert response.status_code == 422


def test_partner_order_idempotency_prevents_duplicate_orders(
    client: TestClient, db_session: Session
) -> None:
    partner, token = _create_partner(db_session, mobile="9800000006")
    p1, _, _ = _create_products(db_session)

    order_payload = {
        "items": [{"product_id": p1.id, "quantity": 3}],
        "idempotency_key": "unique-client-order-key-12345",
        "notes": "Testing idempotency",
    }

    # First attempt
    resp1 = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json=order_payload,
    )
    assert resp1.status_code == 201
    order1 = resp1.json()

    # Second attempt with same idempotency key
    resp2 = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json=order_payload,
    )
    assert resp2.status_code == 200 or resp2.status_code == 201
    order2 = resp2.json()

    # Must return the SAME order, without duplicating rows in DB
    assert order1["id"] == order2["id"]
    assert order1["order_number"] == order2["order_number"]

    # Verify order count in DB for this partner is exactly 1
    orders_in_db = db_session.query(Order).filter(Order.partner_id == partner.id).all()
    assert len(orders_in_db) == 1


def test_order_detail_and_pdf_download_authorization(client: TestClient, db_session: Session) -> None:
    partner1, token1 = _create_partner(db_session, mobile="9800000007", name="Partner One")
    _, token2 = _create_partner(db_session, mobile="9800000008", name="Partner Two")
    p1, _, _ = _create_products(db_session)

    # Partner 1 creates an order
    resp = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token1}"},
        json={"items": [{"product_id": p1.id, "quantity": 1}]},
    )
    order_id = resp.json()["id"]

    # Partner 1 can view details
    view_resp = client.get(
        f"/api/v1/orders/{order_id}",
        headers={"Authorization": f"Bearer {token1}"},
    )
    assert view_resp.status_code == 200
    assert view_resp.json()["id"] == order_id

    # Partner 2 CANNOT view Partner 1's order (Forbidden 403)
    p2_resp = client.get(
        f"/api/v1/orders/{order_id}",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert p2_resp.status_code == 403
    assert "Access denied" in p2_resp.json()["detail"]

    # Partner 1 can download PDF
    pdf_resp = client.get(
        f"/api/v1/orders/{order_id}/pdf",
        headers={"Authorization": f"Bearer {token1}"},
    )
    assert pdf_resp.status_code == 200
    assert pdf_resp.headers["content-type"] == "application/pdf"
    assert pdf_resp.content.startswith(b"%PDF")
    assert "Score_Order_" in pdf_resp.headers["content-disposition"]

    # Partner 2 CANNOT download Partner 1's PDF
    p2_pdf_resp = client.get(
        f"/api/v1/orders/{order_id}/pdf",
        headers={"Authorization": f"Bearer {token2}"},
    )
    assert p2_pdf_resp.status_code == 403


def test_whatsapp_delivery_reports_missing_credentials_gracefully(
    client: TestClient, db_session: Session
) -> None:
    _, token = _create_partner(db_session, mobile="9800000009")
    p1, _, _ = _create_products(db_session)

    resp = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json={"items": [{"product_id": p1.id, "quantity": 1}]},
    )
    order_id = resp.json()["id"]

    # Trigger WhatsApp delivery with unconfigured credentials
    with patch("app.services.whatsapp_service.whatsapp_service.is_configured", return_value=False):
        wa_resp = client.post(
            f"/api/v1/orders/{order_id}/send-whatsapp",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert wa_resp.status_code == 200
        wa_data = wa_resp.json()
        assert wa_data["success"] is False
        assert wa_data["status"] == "missing_credentials"
        assert "WHATSAPP_API_TOKEN" in wa_data["message"]


def test_whatsapp_delivery_mocked_success(client: TestClient, db_session: Session) -> None:
    _, token = _create_partner(db_session, mobile="9800000010")
    p1, _, _ = _create_products(db_session)

    resp = client.post(
        "/api/v1/orders",
        headers={"Authorization": f"Bearer {token}"},
        json={"items": [{"product_id": p1.id, "quantity": 1}]},
    )
    order_id = resp.json()["id"]

    # Mock successful Meta Graph API upload & send calls
    mock_upload_resp = MagicMock()
    mock_upload_resp.status_code = 200
    mock_upload_resp.json.return_value = {"id": "meta_media_12345"}

    mock_send_resp = MagicMock()
    mock_send_resp.status_code = 200
    mock_send_resp.json.return_value = {"messages": [{"id": "wamid.HBgLM...="}]}

    mock_client = MagicMock()
    mock_client.post.side_effect = [mock_upload_resp, mock_send_resp]

    with patch.object(httpx, "Client", return_value=mock_client):
        with patch("app.services.whatsapp_service.whatsapp_service.is_configured", return_value=True):
            with patch("app.services.whatsapp_service.whatsapp_service.api_token", "fake_token"):
                with patch("app.services.whatsapp_service.whatsapp_service.phone_number_id", "123456789"):
                    wa_resp = client.post(
                        f"/api/v1/orders/{order_id}/send-whatsapp",
                        headers={"Authorization": f"Bearer {token}"},
                    )
                    assert wa_resp.status_code == 200
                    wa_data = wa_resp.json()
                    assert wa_data["success"] is True
                    assert wa_data["status"] == "delivered"
                    assert wa_data["message_id"] == "wamid.HBgLM...="


def test_partner_login_and_me(client: TestClient, db_session: Session) -> None:
    partner, _ = _create_partner(db_session, mobile="9811122233", name="Direct Partner")

    # Login
    login_resp = client.post(
        "/api/v1/auth/partner/login",
        json={"mobile": "9811122233", "password": "PartnerSecret123"},
    )
    assert login_resp.status_code == 200
    login_data = login_resp.json()
    assert "access_token" in login_data
    assert login_data["user"]["role"] == "partner"
    assert login_data["user"]["partner_profile"]["business_name"] == "Rahul Auto Spares"

    # Profile Me
    token = login_data["access_token"]
    me_resp = client.get(
        "/api/v1/auth/partner/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert me_resp.status_code == 200
    assert me_resp.json()["id"] == partner.id
    assert me_resp.json()["name"] == "Direct Partner"
