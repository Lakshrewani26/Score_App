from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, decode_access_token, hash_password
from app.models import User


def _create_test_user(
    db: Session,
    *,
    name: str = "Test Admin",
    mobile: str = "9876543210",
    password: str = "AdminSecret123!",
    role: str = "admin",
    is_active: bool = True,
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        password_hash=hash_password(password),
        role=role,
        is_active=is_active,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def test_admin_login_success(client: TestClient, db_session: Session) -> None:
    admin = _create_test_user(
        db_session,
        name="Chief Admin",
        mobile="9876543210",
        password="SuperPassword123",
        role="admin",
    )

    response = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543210", "password": "SuperPassword123"},
    )

    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["expires_in"] > 0
    assert data["user"]["id"] == admin.id
    assert data["user"]["name"] == "Chief Admin"
    assert data["user"]["mobile"] == "9876543210"
    assert data["user"]["role"] == "admin"
    assert data["user"]["is_active"] is True

    # Verify token payload
    payload = decode_access_token(data["access_token"])
    assert payload["sub"] == str(admin.id)
    assert payload["role"] == "admin"
    assert payload["mobile"] == "9876543210"


def test_admin_login_nonexistent_account(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9999999999", "password": "AnyPassword123"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid mobile number or password"


def test_admin_login_incorrect_password(client: TestClient, db_session: Session) -> None:
    _create_test_user(
        db_session,
        mobile="9876543210",
        password="CorrectPassword123",
        role="admin",
    )

    response = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543210", "password": "WrongPassword456"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid mobile number or password"


def test_admin_login_deactivated_account(client: TestClient, db_session: Session) -> None:
    _create_test_user(
        db_session,
        mobile="9876543210",
        password="ValidPassword123",
        role="admin",
        is_active=False,
    )

    response = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543210", "password": "ValidPassword123"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Account is deactivated"


@pytest.mark.parametrize("role", ["customer", "partner", "staff"])
def test_non_admin_roles_denied_admin_login(
    client: TestClient, db_session: Session, role: str
) -> None:
    _create_test_user(
        db_session,
        name=f"User {role}",
        mobile=f"987654320{role[0]}",
        password="Password123!",
        role=role,
        is_active=True,
    )

    response = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": f"987654320{role[0]}", "password": "Password123!"},
    )
    assert response.status_code == 403
    assert "Admin privileges required" in response.json()["detail"]


def test_admin_me_successful_access(client: TestClient, db_session: Session) -> None:
    admin = _create_test_user(
        db_session,
        name="Admin Ops",
        mobile="9876543210",
        password="Password123!",
        role="admin",
    )
    token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)

    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == admin.id
    assert data["name"] == "Admin Ops"
    assert data["mobile"] == "9876543210"
    assert data["role"] == "admin"
    assert data["is_active"] is True


def test_admin_me_missing_token(client: TestClient) -> None:
    response = client.get("/api/v1/admin/me")
    assert response.status_code == 401
    assert "credentials were not provided" in response.json()["detail"]


def test_admin_me_malformed_token(client: TestClient) -> None:
    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": "Bearer not-a-valid-jwt-token"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid authentication token"


def test_admin_me_invalid_auth_scheme(client: TestClient) -> None:
    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": "Basic dXNlcjpwYXNz"},
    )
    assert response.status_code == 401


def test_admin_me_expired_token(client: TestClient, db_session: Session) -> None:
    admin = _create_test_user(db_session, role="admin")
    expired_token = create_access_token(
        subject=str(admin.id),
        role="admin",
        expires_delta=timedelta(seconds=-10),
    )

    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {expired_token}"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Token has expired"


@pytest.mark.parametrize("role", ["customer", "partner", "staff"])
def test_admin_me_denied_for_non_admin_token(
    client: TestClient, db_session: Session, role: str
) -> None:
    user = _create_test_user(db_session, role=role, mobile=f"912345678{role[0]}")
    token = create_access_token(subject=str(user.id), role=role)

    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403
    assert "Admin privileges required" in response.json()["detail"]


def test_admin_me_account_no_longer_exists(client: TestClient) -> None:
    # Token generated for an ID not present in db
    token = create_access_token(subject="99999", role="admin")

    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "User account no longer exists"


def test_admin_me_deactivated_admin_account(client: TestClient, db_session: Session) -> None:
    admin = _create_test_user(db_session, role="admin", is_active=False)
    token = create_access_token(subject=str(admin.id), role="admin")

    response = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Account is deactivated"
