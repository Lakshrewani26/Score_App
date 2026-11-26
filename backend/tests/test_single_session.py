from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import SESSION_REVOKED_DETAIL, hash_password
from app.models import CustomerProfile, PartnerProfile, StaffProfile, User


def _create_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
    password: str = "SecurePass123!",
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        role=role,
        is_active=True,
        password_hash=hash_password(password),
    )
    db.add(user)
    db.flush()
    return user


def test_single_active_session_customer(client: TestClient, db_session: Session) -> None:
    """Device A logs in, then Device B logs in. Device A's session is revoked."""
    user = _create_user(db_session, name="Customer One", mobile="9876543210", role="customer")
    db_session.add(CustomerProfile(user_id=user.id))
    db_session.commit()

    # Device A login
    login_a = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9876543210", "password": "SecurePass123!"},
    )
    assert login_a.status_code == 200
    token_a = login_a.json()["access_token"]

    # Device A can access protected endpoint
    res_a = client.get("/api/v1/auth/customer/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a.status_code == 200

    # Device B login (same account)
    login_b = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9876543210", "password": "SecurePass123!"},
    )
    assert login_b.status_code == 200
    token_b = login_b.json()["access_token"]
    assert token_a != token_b

    # Device B succeeds
    res_b = client.get("/api/v1/auth/customer/me", headers={"Authorization": f"Bearer {token_b}"})
    assert res_b.status_code == 200

    # Device A's previous session is now INVALID (HTTP 401 with session revoked message)
    res_a_after = client.get("/api/v1/auth/customer/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a_after.status_code == 401
    assert res_a_after.json()["detail"] == SESSION_REVOKED_DETAIL


def test_single_active_session_partner(client: TestClient, db_session: Session) -> None:
    user = _create_user(db_session, name="Partner One", mobile="9876543211", role="partner")
    db_session.add(PartnerProfile(user_id=user.id, business_name="Biz", business_address="Addr"))
    db_session.commit()

    # Device A login
    login_a = client.post(
        "/api/v1/auth/partner/login",
        json={"mobile": "9876543211", "password": "SecurePass123!"},
    )
    assert login_a.status_code == 200
    token_a = login_a.json()["access_token"]

    res_a = client.get("/api/v1/auth/partner/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a.status_code == 200

    # Device B login
    login_b = client.post(
        "/api/v1/auth/partner/login",
        json={"mobile": "9876543211", "password": "SecurePass123!"},
    )
    assert login_b.status_code == 200
    token_b = login_b.json()["access_token"]

    # Device A is revoked
    res_a_revoked = client.get("/api/v1/auth/partner/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a_revoked.status_code == 401
    assert res_a_revoked.json()["detail"] == SESSION_REVOKED_DETAIL

    # Device B continues to work
    res_b = client.get("/api/v1/auth/partner/me", headers={"Authorization": f"Bearer {token_b}"})
    assert res_b.status_code == 200


def test_single_active_session_staff(client: TestClient, db_session: Session) -> None:
    user = _create_user(db_session, name="Staff One", mobile="9876543212", role="staff")
    db_session.add(StaffProfile(user_id=user.id, staff_id="STF-SS-01"))
    db_session.commit()

    # Device A login
    login_a = client.post(
        "/api/v1/auth/staff/login",
        json={"staff_id": "STF-SS-01", "password": "SecurePass123!"},
    )
    assert login_a.status_code == 200
    token_a = login_a.json()["access_token"]

    res_a = client.get("/api/v1/staff/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a.status_code == 200

    # Device B login
    login_b = client.post(
        "/api/v1/auth/staff/login",
        json={"staff_id": "STF-SS-01", "password": "SecurePass123!"},
    )
    assert login_b.status_code == 200
    token_b = login_b.json()["access_token"]

    # Device A is revoked
    res_a_revoked = client.get("/api/v1/staff/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a_revoked.status_code == 401
    assert res_a_revoked.json()["detail"] == SESSION_REVOKED_DETAIL


def test_single_active_session_admin(client: TestClient, db_session: Session) -> None:
    _create_user(db_session, name="Admin One", mobile="9876543213", role="admin")
    db_session.commit()

    login_a = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543213", "password": "SecurePass123!"},
    )
    assert login_a.status_code == 200
    token_a = login_a.json()["access_token"]

    res_a = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a.status_code == 200

    login_b = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543213", "password": "SecurePass123!"},
    )
    assert login_b.status_code == 200
    token_b = login_b.json()["access_token"]

    res_a_revoked = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token_a}"})
    assert res_a_revoked.status_code == 401
    assert res_a_revoked.json()["detail"] == SESSION_REVOKED_DETAIL


def test_logout_invalidates_session(client: TestClient, db_session: Session) -> None:
    """Logout invalidates the current session token."""
    _create_user(db_session, name="Admin Logout", mobile="9876543214", role="admin")
    db_session.commit()

    login = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543214", "password": "SecurePass123!"},
    )
    token = login.json()["access_token"]

    # Endpoint works
    assert client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token}"}).status_code == 200

    # Logout
    logout_res = client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
    assert logout_res.status_code == 200

    # Token is now rejected
    after = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token}"})
    assert after.status_code == 401
    assert after.json()["detail"] == SESSION_REVOKED_DETAIL


def test_legacy_token_without_sid_rejected_when_active_session_exists(
    client: TestClient, db_session: Session
) -> None:
    """A legacy token without 'sid' claim must be rejected once the account has a session."""
    user = _create_user(db_session, name="Legacy User", mobile="9876543215", role="admin")
    db_session.commit()

    # User logs in, establishing a session_token on the user record
    login_res = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543215", "password": "SecurePass123!"},
    )
    assert login_res.status_code == 200

    # Mint a legacy token without 'sid'
    from app.core.security import create_access_token
    legacy_token = create_access_token(
        subject=str(user.id),
        role="admin",
        mobile=user.mobile,
        session_id=None,  # No sid claim!
    )

    # Legacy token must be REJECTED because active session has an sid
    res = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {legacy_token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == SESSION_REVOKED_DETAIL


def test_token_with_sid_rejected_when_session_cleared_to_none(
    client: TestClient, db_session: Session
) -> None:
    """A token carrying an 'sid' must be rejected if user.session_token was cleared to None."""
    user = _create_user(db_session, name="Cleared User", mobile="9876543216", role="admin")
    db_session.commit()

    # Create a token with an sid
    from app.core.security import create_access_token
    token = create_access_token(
        subject=str(user.id),
        role="admin",
        mobile=user.mobile,
        session_id="some-arbitrary-session-id",
    )

    # user.session_token is currently None
    assert user.session_token is None

    res = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 401
    assert res.json()["detail"] == SESSION_REVOKED_DETAIL


def test_expired_token_rejected(client: TestClient, db_session: Session) -> None:
    """An expired token must return 401."""
    from datetime import timedelta
    from app.core.security import create_access_token

    user = _create_user(db_session, name="Expired User", mobile="9876543217", role="admin")
    db_session.commit()

    expired_token = create_access_token(
        subject=str(user.id),
        role="admin",
        mobile=user.mobile,
        expires_delta=timedelta(seconds=-10),  # expired 10s ago
        session_id="exp-sid",
    )
    user.session_token = "exp-sid"
    db_session.commit()

    res = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {expired_token}"})
    assert res.status_code == 401
    assert "expired" in res.json()["detail"].lower()


def test_admin_password_change_invalidates_current_session(
    client: TestClient, db_session: Session
) -> None:
    """When an admin changes their password, all active sessions are invalidated immediately."""
    user = _create_user(
        db_session,
        name="PW Admin",
        mobile="9876543218",
        role="admin",
        password="OldSecurePass123!",
    )
    db_session.commit()

    # Log in
    login_res = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543218", "password": "OldSecurePass123!"},
    )
    assert login_res.status_code == 200
    token = login_res.json()["access_token"]

    # Endpoint works with token
    res = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200

    # Change password
    change_res = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "OldSecurePass123!",
            "new_password": "NewSecurePass456!",
        },
    )
    assert change_res.status_code == 200

    # Old token must now be rejected immediately!
    after_res = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {token}"})
    assert after_res.status_code == 401
    assert after_res.json()["detail"] == SESSION_REVOKED_DETAIL

    # Old password cannot log in
    old_login = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543218", "password": "OldSecurePass123!"},
    )
    assert old_login.status_code == 401

    # New password can log in and gets fresh valid session
    new_login = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543218", "password": "NewSecurePass456!"},
    )
    assert new_login.status_code == 200
    new_token = new_login.json()["access_token"]
    assert new_token != token

    valid_res = client.get("/api/v1/admin/me", headers={"Authorization": f"Bearer {new_token}"})
    assert valid_res.status_code == 200


def test_user_deactivation_by_admin_revokes_active_session(
    client: TestClient, db_session: Session
) -> None:
    """When an admin deactivates a user account, their session token is revoked."""
    admin = _create_user(db_session, name="Admin Dec", mobile="9876543219", role="admin")
    customer = _create_user(db_session, name="Customer Dec", mobile="9876543220", role="customer")
    db_session.add(CustomerProfile(user_id=customer.id))
    db_session.commit()

    admin_login = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9876543219", "password": "SecurePass123!"},
    )
    admin_token = admin_login.json()["access_token"]

    cust_login = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9876543220", "password": "SecurePass123!"},
    )
    cust_token = cust_login.json()["access_token"]

    # Customer can access endpoint
    res = client.get("/api/v1/auth/customer/me", headers={"Authorization": f"Bearer {cust_token}"})
    assert res.status_code == 200

    # Admin deactivates the customer
    deact_res = client.post(
        f"/api/v1/admin/users/{customer.id}/status",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"is_active": False},
    )
    assert deact_res.status_code == 200

    # Customer token is now blocked because account is deactivated (403) and session revoked
    res_after = client.get("/api/v1/auth/customer/me", headers={"Authorization": f"Bearer {cust_token}"})
    assert res_after.status_code == 403
    assert "deactivated" in res_after.json()["detail"].lower()

    # Verify session_token in DB was set to "REVOKED"
    db_session.expire_all()
    user_db = db_session.get(User, customer.id)
    assert user_db.session_token == "REVOKED"


