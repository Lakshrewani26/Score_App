from __future__ import annotations

from datetime import timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password, verify_password
from app.models import User


def _create_user(
    db: Session,
    *,
    name: str = "Test Admin",
    mobile: str = "9876543210",
    password: str = "InitialPassword123!",
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


def test_admin_password_update_success(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, mobile="9876543210", password="OldPassword123!")
    token = create_access_token(subject=str(admin.id), role="admin", mobile=admin.mobile)

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "OldPassword123!",
            "new_password": "NewSecurePassword456!",
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["message"] == "Password updated successfully"

    # Verify stored password is hash and verify_password works
    db_session.expire_all()
    updated_admin = db_session.get(User, admin.id)
    assert updated_admin is not None
    assert updated_admin.password_hash != "NewSecurePassword456!"
    assert updated_admin.password_hash.startswith("$2b$")
    assert verify_password("NewSecurePassword456!", updated_admin.password_hash) is True
    assert verify_password("OldPassword123!", updated_admin.password_hash) is False

    # Verify old password cannot log in
    old_login_resp = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": admin.mobile, "password": "OldPassword123!"},
    )
    assert old_login_resp.status_code == 401

    # Verify new password logs in successfully
    new_login_resp = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": admin.mobile, "password": "NewSecurePassword456!"},
    )
    assert new_login_resp.status_code == 200
    assert "access_token" in new_login_resp.json()


def test_password_update_missing_authentication(client: TestClient) -> None:
    response = client.post(
        "/api/v1/admin/me/password",
        json={
            "current_password": "OldPassword123!",
            "new_password": "NewSecurePassword456!",
        },
    )
    assert response.status_code == 401
    assert "credentials were not provided" in response.json()["detail"]


def test_password_update_invalid_token(client: TestClient) -> None:
    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": "Bearer malformed.invalid.token"},
        json={
            "current_password": "OldPassword123!",
            "new_password": "NewSecurePassword456!",
        },
    )
    assert response.status_code == 401
    assert "Invalid authentication token" in response.json()["detail"]


def test_password_update_expired_token(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, mobile="9876543210")
    expired_token = create_access_token(
        subject=str(admin.id),
        role="admin",
        expires_delta=timedelta(seconds=-10),
    )

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {expired_token}"},
        json={
            "current_password": "InitialPassword123!",
            "new_password": "NewSecurePassword456!",
        },
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Token has expired"


def test_password_update_incorrect_current_password(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_user(db_session, mobile="9876543210", password="CorrectPassword123!")
    token = create_access_token(subject=str(admin.id), role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "WrongPassword999!",
            "new_password": "NewSecurePassword456!",
        },
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "Current password is incorrect"

    # Verify password was not altered
    db_session.expire_all()
    user = db_session.get(User, admin.id)
    assert verify_password("CorrectPassword123!", user.password_hash) is True


def test_password_update_rejects_identical_new_password(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_user(db_session, mobile="9876543210", password="SamePassword123!")
    token = create_access_token(subject=str(admin.id), role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "SamePassword123!",
            "new_password": "SamePassword123!",
        },
    )
    assert response.status_code == 400
    assert "different from current password" in response.json()["detail"]


@pytest.mark.parametrize(
    "invalid_password",
    [
        "short",          # < 8 characters
        "",               # empty
        "   ",            # whitespace only
        "1234567",        # 7 characters
    ],
)
def test_password_update_enforces_policy(
    client: TestClient, db_session: Session, invalid_password: str
) -> None:
    admin = _create_user(db_session, mobile="9876543210", password="ValidInitial123!")
    token = create_access_token(subject=str(admin.id), role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "ValidInitial123!",
            "new_password": invalid_password,
        },
    )
    assert response.status_code == 422  # Pydantic validation failure


def test_password_update_does_not_affect_other_users(
    client: TestClient, db_session: Session
) -> None:
    admin1 = _create_user(db_session, name="Admin 1", mobile="9876543210", password="Admin1Password!")
    admin2 = _create_user(db_session, name="Admin 2", mobile="9876543211", password="Admin2Password!")
    partner = _create_user(db_session, name="Partner 1", mobile="9876543212", password="PartnerPassword!", role="partner")

    token1 = create_access_token(subject=str(admin1.id), role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token1}"},
        json={
            "current_password": "Admin1Password!",
            "new_password": "NewAdmin1Password999!",
        },
    )
    assert response.status_code == 200

    db_session.expire_all()
    user2 = db_session.get(User, admin2.id)
    user_partner = db_session.get(User, partner.id)

    assert verify_password("Admin2Password!", user2.password_hash) is True
    assert user2.role == "admin"
    assert user2.is_active is True

    assert verify_password("PartnerPassword!", user_partner.password_hash) is True
    assert user_partner.role == "partner"
    assert user_partner.is_active is True


def test_password_update_no_secrets_returned(client: TestClient, db_session: Session) -> None:
    admin = _create_user(db_session, mobile="9876543210", password="SecretPassword123!")
    token = create_access_token(subject=str(admin.id), role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "SecretPassword123!",
            "new_password": "BrandNewPassword456!",
        },
    )
    assert response.status_code == 200
    data = response.json()

    forbidden_keys = {"password", "password_hash", "hash", "secret", "token", "access_token"}
    for key in data.keys():
        assert key.lower() not in forbidden_keys

    # Response should only contain safe message
    assert set(data.keys()) == {"message"}


def test_password_update_deactivated_admin_rejected(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_user(
        db_session,
        mobile="9876543210",
        password="ActivePassword123!",
        is_active=False,
    )
    token = create_access_token(subject=str(admin.id), role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "ActivePassword123!",
            "new_password": "NewPassword789!",
        },
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Account is deactivated"


def test_password_update_deleted_admin_rejected(client: TestClient) -> None:
    token = create_access_token(subject="99999", role="admin")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "AnyPassword123!",
            "new_password": "NewPassword789!",
        },
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "User account no longer exists"


def test_non_admin_token_rejected(client: TestClient, db_session: Session) -> None:
    partner = _create_user(db_session, mobile="9876543210", role="partner")
    token = create_access_token(subject=str(partner.id), role="partner")

    response = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "InitialPassword123!",
            "new_password": "NewPassword789!",
        },
    )
    assert response.status_code == 403
    assert "Admin privileges required" in response.json()["detail"]
