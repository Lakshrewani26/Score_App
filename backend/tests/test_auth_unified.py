from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import decode_access_token, hash_password
from app.models import CustomerProfile, PartnerProfile, StaffProfile, User


def _create_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
    password: str = "TestSecret123!",
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


def _create_customer(
    db: Session,
    *,
    name: str = "Customer One",
    mobile: str = "9876543201",
    password: str = "CustomerPass123!",
    is_active: bool = True,
    state: str = "Maharashtra",
    city: str = "Mumbai",
    segment: str = "2-Wheeler",
) -> User:
    user = _create_user(
        db, name=name, mobile=mobile, role="customer", password=password, is_active=is_active
    )
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


def _create_partner(
    db: Session,
    *,
    name: str = "Partner One",
    mobile: str = "9876543202",
    password: str = "PartnerPass123!",
    is_active: bool = True,
    business_name: str = "Auto Parts Dealer",
    business_address: str = "123 Main Street, Pune",
    partner_code: str = "PRT-001",
) -> User:
    user = _create_user(
        db, name=name, mobile=mobile, role="partner", password=password, is_active=is_active
    )
    profile = PartnerProfile(
        user_id=user.id,
        business_name=business_name,
        business_address=business_address,
        partner_code=partner_code,
    )
    db.add(profile)
    db.commit()
    db.refresh(user)
    return user


def _create_staff(
    db: Session,
    *,
    name: str = "Staff One",
    mobile: str = "9876543203",
    password: str = "StaffPass123!",
    is_active: bool = True,
    staff_id: str = "STF-101",
) -> User:
    user = _create_user(
        db, name=name, mobile=mobile, role="staff", password=password, is_active=is_active
    )
    profile = StaffProfile(
        user_id=user.id,
        staff_id=staff_id,
    )
    db.add(profile)
    db.commit()
    db.refresh(user)
    return user


def _create_admin(
    db: Session,
    *,
    name: str = "Admin One",
    mobile: str = "9876543204",
    password: str = "AdminPass123!",
    is_active: bool = True,
) -> User:
    return _create_user(
        db, name=name, mobile=mobile, role="admin", password=password, is_active=is_active
    )


# --- 1-4: Successful Authentication for All Roles ---

def test_unified_login_customer_success(client: TestClient, db_session: Session) -> None:
    customer = _create_customer(db_session, mobile="9876543210", password="Password123!")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543210", "password": "Password123!"},
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["role"] == "customer"
    assert data["user_id"] == customer.id
    assert data["name"] == "Customer One"
    assert data["mobile"] == "9876543210"
    assert data["is_active"] is True
    assert data["customer_profile"]["state"] == "Maharashtra"
    assert data["customer_profile"]["city"] == "Mumbai"
    assert data["customer_profile"]["segment"] == "2-Wheeler"
    assert data["user"]["role"] == "customer"
    assert data["user"]["id"] == customer.id

    # Verify JWT token
    payload = decode_access_token(data["access_token"])
    assert payload["sub"] == str(customer.id)
    assert payload["role"] == "customer"


def test_unified_login_partner_success(client: TestClient, db_session: Session) -> None:
    partner = _create_partner(db_session, mobile="9876543211", password="Password123!")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543211", "password": "Password123!"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "partner"
    assert data["user_id"] == partner.id
    assert data["name"] == "Partner One"
    assert data["mobile"] == "9876543211"
    assert data["partner_profile"]["business_name"] == "Auto Parts Dealer"
    assert data["partner_profile"]["partner_code"] == "PRT-001"
    assert data["user"]["role"] == "partner"

    payload = decode_access_token(data["access_token"])
    assert payload["sub"] == str(partner.id)
    assert payload["role"] == "partner"


def test_unified_login_staff_success(client: TestClient, db_session: Session) -> None:
    staff = _create_staff(db_session, mobile="9876543212", password="Password123!", staff_id="STF-777")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543212", "password": "Password123!"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "staff"
    assert data["user_id"] == staff.id
    assert data["name"] == "Staff One"
    assert data["mobile"] == "9876543212"
    assert data["staff_id"] == "STF-777"
    assert data["user"]["staff_id"] == "STF-777"
    assert data["user"]["role"] == "staff"

    payload = decode_access_token(data["access_token"])
    assert payload["sub"] == str(staff.id)
    assert payload["role"] == "staff"


def test_unified_login_admin_success(client: TestClient, db_session: Session) -> None:
    admin = _create_admin(db_session, mobile="9876543213", password="Password123!")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543213", "password": "Password123!"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["role"] == "admin"
    assert data["user_id"] == admin.id
    assert data["name"] == "Admin One"
    assert data["mobile"] == "9876543213"
    assert data["user"]["role"] == "admin"

    payload = decode_access_token(data["access_token"])
    assert payload["sub"] == str(admin.id)
    assert payload["role"] == "admin"


# --- 5-7: Staff Login Details ---

def test_staff_phone_login_succeeds(client: TestClient, db_session: Session) -> None:
    _create_staff(db_session, mobile="9876543214", password="StaffSecret123!", staff_id="STF-888")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543214", "password": "StaffSecret123!"},
    )
    assert response.status_code == 200
    assert response.json()["role"] == "staff"


def test_staff_employee_id_in_phone_field_fails(client: TestClient, db_session: Session) -> None:
    _create_staff(db_session, mobile="9876543215", password="StaffSecret123!", staff_id="STF-888")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "STF-888", "password": "StaffSecret123!"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid mobile number or password"


def test_staff_id_retained_in_authenticated_response(client: TestClient, db_session: Session) -> None:
    _create_staff(db_session, mobile="9876543216", password="StaffSecret123!", staff_id="EMP-999")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543216", "password": "StaffSecret123!"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["staff_id"] == "EMP-999"
    assert data["user"]["staff_id"] == "EMP-999"


# --- 8-15: Security Requirements ---

def test_unified_login_incorrect_password_returns_generic_error(
    client: TestClient, db_session: Session
) -> None:
    _create_customer(db_session, mobile="9876543220", password="CorrectPassword123!")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543220", "password": "WrongPassword!"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid mobile number or password"


def test_unified_login_unknown_phone_returns_same_generic_error(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9999999999", "password": "AnyPassword123!"},
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid mobile number or password"


def test_unified_login_errors_do_not_reveal_role(
    client: TestClient, db_session: Session
) -> None:
    _create_customer(db_session, mobile="9876543230", password="Pass1")
    _create_partner(db_session, mobile="9876543231", password="Pass2")
    _create_staff(db_session, mobile="9876543232", password="Pass3")
    _create_admin(db_session, mobile="9876543233", password="Pass4")

    # All incorrect password attempts return identical generic messages
    for mobile in ["9876543230", "9876543231", "9876543232", "9876543233", "9999999999"]:
        res = client.post("/api/v1/auth/login", json={"mobile": mobile, "password": "WrongPassword"})
        assert res.status_code == 401
        assert res.json()["detail"] == "Invalid mobile number or password"


def test_unified_login_inactive_account_rejected(
    client: TestClient, db_session: Session
) -> None:
    _create_customer(db_session, mobile="9876543240", password="Password123!", is_active=False)
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543240", "password": "Password123!"},
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "Account is deactivated"


def test_unified_login_jwt_token_validity_and_role_match(
    client: TestClient, db_session: Session
) -> None:
    staff = _create_staff(db_session, mobile="9876543250", password="Password123!", staff_id="STF-50")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543250", "password": "Password123!"},
    )
    assert response.status_code == 200
    token = response.json()["access_token"]
    payload = decode_access_token(token)
    assert payload["sub"] == str(staff.id)
    assert payload["role"] == "staff"
    assert payload["mobile"] == "9876543250"


def test_unified_login_role_authorization_working(
    client: TestClient, db_session: Session
) -> None:
    staff = _create_staff(db_session, mobile="9876543260", password="Password123!", staff_id="STF-60")
    admin = _create_admin(db_session, mobile="9876543261", password="Password123!")

    staff_login = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543260", "password": "Password123!"},
    )
    admin_login = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543261", "password": "Password123!"},
    )

    staff_token = staff_login.json()["access_token"]
    admin_token = admin_login.json()["access_token"]

    # Staff can access /staff/me
    staff_me = client.get(
        "/api/v1/staff/me",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert staff_me.status_code == 200

    # Staff CANNOT access /admin/me
    admin_me_denied = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {staff_token}"},
    )
    assert admin_me_denied.status_code == 403

    # Admin CAN access /admin/me
    admin_me = client.get(
        "/api/v1/admin/me",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert admin_me.status_code == 200


def test_unified_login_never_returns_password_hash(
    client: TestClient, db_session: Session
) -> None:
    _create_customer(db_session, mobile="9876543270", password="Password123!")
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543270", "password": "Password123!"},
    )
    assert response.status_code == 200
    res_text = response.text.lower()
    assert "password_hash" not in res_text
    assert "hash" not in res_text
    data = response.json()
    assert "password" not in data
    assert "password_hash" not in data
    assert "password_hash" not in data["user"]


# --- 16-20: Validation ---

def test_unified_login_missing_phone(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"password": "Password123!"},
    )
    assert response.status_code == 422


def test_unified_login_empty_phone(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "", "password": "Password123!"},
    )
    assert response.status_code == 422

    response_spaces = client.post(
        "/api/v1/auth/login",
        json={"mobile": "   ", "password": "Password123!"},
    )
    assert response_spaces.status_code == 422


def test_unified_login_missing_password(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543210"},
    )
    assert response.status_code == 422


def test_unified_login_empty_password(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"mobile": "9876543210", "password": ""},
    )
    assert response.status_code == 422


def test_unified_login_invalid_request_format(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login",
        content="not-json",
        headers={"Content-Type": "application/json"},
    )
    assert response.status_code == 422


# --- 21-24: Compatibility with Existing Workflows ---

def test_existing_customer_registration_continues_working(
    client: TestClient, db_session: Session
) -> None:
    response = client.post(
        "/api/v1/auth/customer/register",
        json={
            "name": "New Customer",
            "mobile": "9111222333",
            "password": "RegisterPassword123",
            "state": "Gujarat",
            "city": "Ahmedabad",
            "segment": "2-Wheeler",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["user"]["role"] == "customer"
    assert data["user"]["name"] == "New Customer"


def test_existing_role_specific_endpoints_continue_working(
    client: TestClient, db_session: Session
) -> None:
    _create_customer(db_session, mobile="9888800001", password="PassCustomer")
    _create_partner(db_session, mobile="9888800002", password="PassPartner")
    _create_staff(db_session, mobile="9888800003", password="PassStaff", staff_id="STF-OLD")
    _create_admin(db_session, mobile="9888800004", password="PassAdmin")

    # Customer endpoint
    c_res = client.post(
        "/api/v1/auth/customer/login",
        json={"mobile": "9888800001", "password": "PassCustomer"},
    )
    assert c_res.status_code == 200

    # Partner endpoint
    p_res = client.post(
        "/api/v1/auth/partner/login",
        json={"mobile": "9888800002", "password": "PassPartner"},
    )
    assert p_res.status_code == 200

    # Staff endpoint (uses staff_id)
    s_res = client.post(
        "/api/v1/auth/staff/login",
        json={"staff_id": "STF-OLD", "password": "PassStaff"},
    )
    assert s_res.status_code == 200

    # Admin endpoint
    a_res = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9888800004", "password": "PassAdmin"},
    )
    assert a_res.status_code == 200


def test_existing_admin_password_update_continues_working(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_admin(db_session, mobile="9888811111", password="OldPassword123!")
    login_res = client.post(
        "/api/v1/auth/admin/login",
        json={"mobile": "9888811111", "password": "OldPassword123!"},
    )
    token = login_res.json()["access_token"]

    update_res = client.post(
        "/api/v1/admin/me/password",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "current_password": "OldPassword123!",
            "new_password": "BrandNewPassword123!",
        },
    )
    assert update_res.status_code == 200
