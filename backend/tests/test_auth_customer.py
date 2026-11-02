from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.models import CustomerProfile, User


def _create_test_customer(
    db: Session,
    *,
    name: str = "Test Customer",
    mobile: str = "9876543210",
    password: str = "CustomerPass123",
    role: str = "customer",
    is_active: bool = True,
    state: str = "Maharashtra",
    city: str = "Pune",
    segment: str = "2-Wheeler",
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password(password),
        role=role,
        is_active=is_active,
    )
    db.add(user)
    db.flush()

    profile = CustomerProfile(
        user_id=user.id,
        state=state,
        city=city,
        segment=segment,
    )
    db.add(profile)
    db.commit()
    db.refresh(user)
    return user


def test_customer_register_success(client: TestClient, db_session: Session) -> None:
    response = client.post(
        "/api/v1/auth/customer/register",
        json={
            "name": "Jane Doe",
            "mobile": "9988776655",
            "password": "Password123!",
            "state": "Maharashtra",
            "city": "Mumbai",
            "segment": "Both",
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["expires_in"] > 0
    assert data["user"]["name"] == "Jane Doe"
    assert data["user"]["mobile"] == "9988776655"
    assert data["user"]["role"] == "customer"
    assert data["user"]["is_active"] is True
    assert data["user"]["customer_profile"]["state"] == "Maharashtra"
    assert data["user"]["customer_profile"]["city"] == "Mumbai"
    assert data["user"]["customer_profile"]["segment"] == "Both"


def test_customer_register_duplicate_mobile_rejected(
    client: TestClient, db_session: Session
) -> None:
    _create_test_customer(db_session, mobile="9988776655")

    response = client.post(
        "/api/v1/auth/customer/register",
        json={
            "name": "Another Person",
            "mobile": "9988776655",
            "password": "Password123!",
        },
    )

    assert response.status_code == 409
    assert "already exists" in response.json()["detail"].lower()


def test_customer_register_short_password_rejected(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/customer/register",
        json={
            "name": "Short Pass User",
            "mobile": "9123456789",
            "password": "123",  # min 6
        },
    )
    assert response.status_code == 422


def test_customer_register_empty_name_rejected(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/customer/register",
        json={
            "name": "   ",
            "mobile": "9123456789",
            "password": "Password123!",
        },
    )
    assert response.status_code == 422


def test_customer_login_success(client: TestClient, db_session: Session) -> None:
    customer = _create_test_customer(
        db_session,
        name="Rahul Sharma",
        mobile="9123456780",
        password="MySecretPassword1",
    )

    response = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9123456780", "password": "MySecretPassword1"},
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["user"]["id"] == customer.id
    assert data["user"]["name"] == "Rahul Sharma"
    assert data["user"]["role"] == "customer"
    assert data["user"]["customer_profile"]["city"] == "Pune"


def test_customer_login_invalid_password(client: TestClient, db_session: Session) -> None:
    _create_test_customer(db_session, mobile="9123456781", password="RealPassword")

    response = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9123456781", "password": "WrongPassword"},
    )

    assert response.status_code == 401
    assert "Invalid mobile number or password" in response.json()["detail"]


def test_customer_login_nonexistent_user(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9000000000", "password": "SomePassword"},
    )

    assert response.status_code == 401
    assert "Invalid mobile number or password" in response.json()["detail"]


def test_customer_login_deactivated_account(client: TestClient, db_session: Session) -> None:
    _create_test_customer(
        db_session, mobile="9123456782", password="ValidPassword", is_active=False
    )

    response = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9123456782", "password": "ValidPassword"},
    )

    assert response.status_code == 403
    assert "deactivated" in response.json()["detail"].lower()


def test_customer_login_denies_partner_role(client: TestClient, db_session: Session) -> None:
    user = User(
        name="Partner Person",
        mobile="9123456783",
        password_hash=hash_password("PartnerPassword"),
        role="partner",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()

    response = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9123456783", "password": "PartnerPassword"},
    )

    assert response.status_code == 403
    assert "Customer privileges required" in response.json()["detail"]


def test_customer_me_success(client: TestClient, db_session: Session) -> None:
    customer = _create_test_customer(
        db_session, mobile="9123456784", name="Me Customer"
    )
    token = create_access_token(subject=str(customer.id), role="customer")

    response = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == customer.id
    assert data["name"] == "Me Customer"
    assert data["role"] == "customer"
    assert data["customer_profile"]["state"] == "Maharashtra"


def test_customer_me_forbidden_for_partner_role(client: TestClient, db_session: Session) -> None:
    user = User(
        name="Partner User",
        mobile="9123456785",
        password_hash=hash_password("Pass123"),
        role="partner",
        is_active=True,
    )
    db_session.add(user)
    db_session.commit()
    token = create_access_token(subject=str(user.id), role="partner")

    response = client.get(
        "/api/v1/auth/customer/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 403
    assert "Customer privileges required" in response.json()["detail"]


def test_customer_registration_endpoint_in_openapi(client: TestClient) -> None:
    """Verifies that customer auth endpoints and staff order endpoints are registered and documented in FastAPI OpenAPI."""
    response = client.get("/openapi.json")
    assert response.status_code == 200
    schema = response.json()
    paths = schema.get("paths", {})
    assert "/api/v1/auth/customer/register" in paths
    assert "/api/v1/auth/customer/login" in paths
    assert "/api/v1/auth/customer/me" in paths
    assert "/api/v1/staff/orders" in paths


def test_customer_registration_and_immediate_login_flow(
    client: TestClient, db_session: Session
) -> None:
    """Verifies full lifecycle: atomic DB creation of User + CustomerProfile, followed by successful login."""
    reg_payload = {
        "name": "Pooja Patel",
        "mobile": "9876500001",
        "password": "SecurePassword99",
        "state": "Gujarat",
        "city": "Ahmedabad",
        "segment": "2-Wheeler",
    }
    reg_res = client.post("/api/v1/auth/customer/register", json=reg_payload)
    assert reg_res.status_code == 201
    reg_data = reg_res.json()
    assert reg_data["user"]["name"] == "Pooja Patel"
    assert reg_data["user"]["role"] == "customer"
    assert reg_data["user"]["customer_profile"]["city"] == "Ahmedabad"

    # Verify atomic DB persistence
    db_session.expire_all()
    user_in_db = db_session.query(User).filter_by(mobile="9876500001").first()
    assert user_in_db is not None
    assert user_in_db.role == "customer"
    assert user_in_db.customer_profile is not None
    assert user_in_db.customer_profile.state == "Gujarat"
    assert user_in_db.customer_profile.city == "Ahmedabad"
    assert user_in_db.customer_profile.segment == "2-Wheeler"

    # Verify customer can immediately log in with the new credentials
    login_res = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9876500001", "password": "SecurePassword99"},
    )
    assert login_res.status_code == 200
    login_data = login_res.json()
    assert login_data["user"]["id"] == user_in_db.id
    assert login_data["access_token"] is not None

    # Verify wrong credentials fail
    bad_login_res = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9876500001", "password": "IncorrectPassword"},
    )
    assert bad_login_res.status_code == 401
