from __future__ import annotations

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.models import PartnerProfile, StaffPartnerAssignment, StaffProfile, User


def _create_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
    active: bool = True,
    password: str = "SecurePassword123!",
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        role=role,
        is_active=active,
        password_hash=hash_password(password),
    )
    db.add(user)
    db.flush()
    return user


def _create_staff(
    db: Session,
    *,
    name: str = "Staff One",
    mobile: str = "9000000001",
    staff_id: str = "STF-001",
    active: bool = True,
) -> User:
    user = _create_user(
        db,
        name=name,
        mobile=mobile,
        role="staff",
        active=active,
    )
    db.add(StaffProfile(user_id=user.id, staff_id=staff_id))
    db.commit()
    db.refresh(user)
    return user


def _create_partner(
    db: Session,
    *,
    name: str = "Partner One",
    mobile: str = "9000000002",
    business_name: str = "Partner Business",
    active: bool = True,
) -> User:
    user = _create_user(
        db,
        name=name,
        mobile=mobile,
        role="partner",
        active=active,
    )
    db.add(
        PartnerProfile(
            user_id=user.id,
            business_name=business_name,
            business_address="Partner address",
        )
    )
    db.commit()
    db.refresh(user)
    return user


def _authorization(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_staff_login_uses_staff_id_and_returns_staff_token(
    client: TestClient, db_session: Session
) -> None:
    staff = _create_staff(db_session)

    response = client.post(
        "/api/v1/auth/staff/login",
        json={"staff_id": "STF-001", "password": "SecurePassword123!"},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["access_token"]
    assert data["token_type"] == "bearer"
    assert data["user"]["id"] == staff.id
    assert data["user"]["staff_id"] == "STF-001"
    assert data["user"]["role"] == "staff"


def test_staff_login_rejects_invalid_credentials_and_inactive_account(
    client: TestClient, db_session: Session
) -> None:
    _create_staff(db_session)
    invalid = client.post(
        "/api/v1/auth/staff/login",
        json={"staff_id": "STF-001", "password": "WrongPassword123!"},
    )
    assert invalid.status_code == 401
    assert invalid.json()["detail"] == "Invalid Staff ID or password"

    inactive_staff = _create_staff(
        db_session,
        name="Inactive Staff",
        mobile="9000000011",
        staff_id="STF-002",
        active=False,
    )
    inactive = client.post(
        "/api/v1/auth/staff/login",
        json={"staff_id": "STF-002", "password": "SecurePassword123!"},
    )
    assert inactive_staff.id
    assert inactive.status_code == 403
    assert inactive.json()["detail"] == "Account is deactivated"


def test_staff_routes_require_staff_auth_and_return_active_assignments(
    client: TestClient, db_session: Session
) -> None:
    staff = _create_staff(db_session)
    partner = _create_partner(db_session)
    inactive_partner = _create_partner(
        db_session,
        name="Inactive Partner",
        mobile="9000000012",
        business_name="Inactive Business",
        active=False,
    )
    db_session.add_all(
        [
            StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id),
            StaffPartnerAssignment(
                staff_id=staff.id,
                partner_id=inactive_partner.id,
                is_active=False,
            ),
        ]
    )
    db_session.commit()

    no_auth = client.get("/api/v1/staff/me")
    assert no_auth.status_code == 401
    admin = _create_user(
        db_session,
        name="Admin",
        mobile="9000000013",
        role="admin",
    )
    db_session.commit()
    forbidden = client.get(
        "/api/v1/staff/partners",
        headers=_authorization(admin),
    )
    assert forbidden.status_code == 403

    headers = _authorization(staff)
    me = client.get("/api/v1/staff/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["staff_id"] == "STF-001"

    partners = client.get("/api/v1/staff/partners", headers=headers)
    assert partners.status_code == 200
    assert len(partners.json()) == 1
    assert partners.json()[0]["id"] == partner.id
    assert partners.json()[0]["business_name"] == "Partner Business"


def test_admin_can_create_and_list_assignments(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_user(
        db_session,
        name="Admin",
        mobile="9000000021",
        role="admin",
    )
    db_session.commit()
    staff = _create_staff(db_session)
    partner = _create_partner(db_session)

    unauthorized = client.get("/api/v1/admin/staff-partner-assignments")
    assert unauthorized.status_code == 401
    non_admin = client.get(
        "/api/v1/admin/staff-partner-assignments",
        headers=_authorization(staff),
    )
    assert non_admin.status_code == 403

    headers = _authorization(admin)
    created = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert created.status_code == 201
    result = created.json()
    assert result["staff_id"] == staff.id
    assert result["partner_id"] == partner.id
    assert result["staff"]["staff_id"] == "STF-001"
    assert result["partner"]["business_name"] == "Partner Business"

    listed = client.get(
        "/api/v1/admin/staff-partner-assignments?is_active=true",
        headers=headers,
    )
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == result["id"]
    assert db_session.query(StaffPartnerAssignment).count() == 1


def test_admin_assignment_rejects_duplicates_wrong_roles_and_inactive_users(
    client: TestClient, db_session: Session
) -> None:
    admin = _create_user(
        db_session,
        name="Admin",
        mobile="9000000031",
        role="admin",
    )
    db_session.commit()
    staff = _create_staff(db_session)
    partner = _create_partner(db_session)
    headers = _authorization(admin)
    endpoint = "/api/v1/admin/staff-partner-assignments"
    body = {"staff_id": staff.id, "partner_id": partner.id}

    assert client.post(endpoint, headers=headers, json=body).status_code == 201
    duplicate = client.post(endpoint, headers=headers, json=body)
    assert duplicate.status_code == 409

    wrong_role = _create_user(
        db_session,
        name="Customer",
        mobile="9000000032",
        role="customer",
    )
    db_session.commit()
    wrong_staff = client.post(
        endpoint,
        headers=headers,
        json={"staff_id": wrong_role.id, "partner_id": partner.id},
    )
    assert wrong_staff.status_code == 422

    inactive_staff = _create_staff(
        db_session,
        name="Inactive Staff",
        mobile="9000000034",
        staff_id="STF-034",
        active=False,
    )
    inactive_staff_response = client.post(
        endpoint,
        headers=headers,
        json={"staff_id": inactive_staff.id, "partner_id": partner.id},
    )
    assert inactive_staff_response.status_code == 422

    inactive_partner = _create_partner(
        db_session,
        name="Inactive Partner",
        mobile="9000000033",
        business_name="Inactive",
        active=False,
    )
    inactive = client.post(
        endpoint,
        headers=headers,
        json={"staff_id": staff.id, "partner_id": inactive_partner.id},
    )
    assert inactive.status_code == 422
