from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.exc import IntegrityError
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


def test_admin_can_deactivate_and_reactivate_assignment(
    client: TestClient, db_session: Session
) -> None:
    # 1. Admin can deactivate an active assignment.
    # 2. Admin can reactivate an inactive assignment.
    # 9. Deactivated assignments remain in the database.
    # 10. Assignment IDs and historical relationships remain unchanged.
    admin = _create_user(db_session, name="Admin", mobile="9000000041", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000042", staff_id="STF-042")
    partner = _create_partner(db_session, name="Partner", mobile="9000000043")
    admin_headers = _authorization(admin)

    # Create active assignment
    res_create = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res_create.status_code == 201
    assignment_id = res_create.json()["id"]
    assigned_at = res_create.json()["assigned_at"]
    assert res_create.json()["is_active"] is True

    # 1. Deactivate assignment
    res_deactivate = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment_id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate.status_code == 200
    deactivated_data = res_deactivate.json()
    assert deactivated_data["id"] == assignment_id
    assert deactivated_data["is_active"] is False
    assert deactivated_data["assigned_at"] == assigned_at
    assert deactivated_data["staff_id"] == staff.id
    assert deactivated_data["partner_id"] == partner.id

    # 9. Verify deactivated assignment remains in database
    db_session.expire_all()
    record = db_session.get(StaffPartnerAssignment, assignment_id)
    assert record is not None
    assert record.is_active is False
    assert record.staff_id == staff.id
    assert record.partner_id == partner.id

    # 2. Reactivate assignment
    res_reactivate = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment_id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_reactivate.status_code == 200
    reactivated_data = res_reactivate.json()
    assert reactivated_data["id"] == assignment_id
    assert reactivated_data["is_active"] is True
    assert reactivated_data["assigned_at"] == assigned_at

    # 10. Verify ID and relationships remain unchanged
    db_session.expire_all()
    record_reactivated = db_session.get(StaffPartnerAssignment, assignment_id)
    assert record_reactivated is not None
    assert record_reactivated.id == assignment_id
    assert record_reactivated.is_active is True
    assert record_reactivated.staff_id == staff.id
    assert record_reactivated.partner_id == partner.id


def test_assignment_status_authorization_and_nonexistent(
    client: TestClient, db_session: Session
) -> None:
    # 3. Unauthenticated users cannot modify assignments.
    # 4. Non-Admin users cannot modify assignments.
    # 5. Nonexistent assignment returns the correct error.
    admin = _create_user(db_session, name="Admin", mobile="9000000051", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000052", staff_id="STF-052")
    partner = _create_partner(db_session, name="Partner", mobile="9000000053")
    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()

    # 3. Unauthenticated
    unauth = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        json={"is_active": False},
    )
    assert unauth.status_code == 401

    # 4. Non-Admin (staff & partner)
    forbidden_staff = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=_authorization(staff),
        json={"is_active": False},
    )
    assert forbidden_staff.status_code == 403

    forbidden_partner = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=_authorization(partner),
        json={"is_active": False},
    )
    assert forbidden_partner.status_code == 403

    # 5. Nonexistent assignment
    not_found = client.patch(
        "/api/v1/admin/staff-partner-assignments/999999/status",
        headers=_authorization(admin),
        json={"is_active": False},
    )
    assert not_found.status_code == 404
    assert not_found.json()["detail"] == "Staff-Partner assignment not found"


def test_repeated_deactivation_and_reactivation_safe(
    client: TestClient, db_session: Session
) -> None:
    # 6. Repeated deactivation is handled safely.
    # 7. Repeated reactivation is handled safely.
    admin = _create_user(db_session, name="Admin", mobile="9000000061", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000062", staff_id="STF-062")
    partner = _create_partner(db_session, name="Partner", mobile="9000000063")
    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()
    admin_headers = _authorization(admin)

    # 7. Repeated reactivation on already active assignment
    res_re_activate = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_re_activate.status_code == 200
    assert res_re_activate.json()["is_active"] is True

    # Deactivate once
    res_deactivate_1 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate_1.status_code == 200
    assert res_deactivate_1.json()["is_active"] is False

    # 6. Repeated deactivation on already inactive assignment
    res_deactivate_2 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate_2.status_code == 200
    assert res_deactivate_2.json()["is_active"] is False

    # Repeated deactivation remains safe and idempotent
    res_deactivate_3 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate_3.status_code == 200
    assert res_deactivate_3.json()["is_active"] is False

    # Reactivate again safely and idempotently
    res_react_1 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_react_1.status_code == 200
    assert res_react_1.json()["is_active"] is True

    # Repeated reactivation on already active assignment remains safe
    res_react_2 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_react_2.status_code == 200
    assert res_react_2.json()["is_active"] is True


def test_reactivation_rejected_when_conflicting_active_assignment_exists(
    client: TestClient, db_session: Session
) -> None:
    # 8. Reactivation is rejected when another active assignment exists for the same Staff–Partner pair.
    admin = _create_user(db_session, name="Admin", mobile="9000000071", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000072", staff_id="STF-072")
    partner = _create_partner(db_session, name="Partner", mobile="9000000073")

    assignment1 = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=False)
    assignment2 = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add_all([assignment1, assignment2])
    db_session.commit()

    admin_headers = _authorization(admin)

    # Attempt to reactivate assignment1 while assignment2 is active
    conflict_res = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment1.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert conflict_res.status_code == 409
    assert "already exists" in conflict_res.json()["detail"].lower()

    # Verify assignment1 is still inactive and assignment2 is still active
    db_session.expire_all()
    reloaded1 = db_session.get(StaffPartnerAssignment, assignment1.id)
    reloaded2 = db_session.get(StaffPartnerAssignment, assignment2.id)
    assert reloaded1 is not None and reloaded1.is_active is False
    assert reloaded2 is not None and reloaded2.is_active is True


def test_staff_partner_list_visibility_with_deactivation_and_reactivation(
    client: TestClient, db_session: Session
) -> None:
    # 11. Staff cannot see deactivated assignments.
    # 12. Staff can see reactivated assignments when both accounts are active.
    admin = _create_user(db_session, name="Admin", mobile="9000000081", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000082", staff_id="STF-082")
    partner = _create_partner(db_session, name="Partner", mobile="9000000083", business_name="Alpha Store")

    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()

    staff_headers = _authorization(staff)
    admin_headers = _authorization(admin)

    # Initially active: partner is visible
    p_init = client.get("/api/v1/staff/partners", headers=staff_headers)
    assert p_init.status_code == 200
    assert len(p_init.json()) == 1
    assert p_init.json()[0]["id"] == partner.id

    # 11. Deactivate assignment: partner must NOT appear in staff list
    client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    p_deact = client.get("/api/v1/staff/partners", headers=staff_headers)
    assert p_deact.status_code == 200
    assert len(p_deact.json()) == 0

    # 12. Reactivate assignment: partner appears again when both accounts are active
    client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    p_react = client.get("/api/v1/staff/partners", headers=staff_headers)
    assert p_react.status_code == 200
    assert len(p_react.json()) == 1
    assert p_react.json()[0]["id"] == partner.id

    # Deactivating partner account hides it even if assignment is active
    partner.is_active = False
    db_session.commit()
    p_inactive_partner = client.get("/api/v1/staff/partners", headers=staff_headers)
    assert p_inactive_partner.status_code == 200
    assert len(p_inactive_partner.json()) == 0

    # Reactivating partner account restores visibility
    partner.is_active = True
    db_session.commit()
    p_restored = client.get("/api/v1/staff/partners", headers=staff_headers)
    assert p_restored.status_code == 200
    assert len(p_restored.json()) == 1


def test_assignment_status_update_schema_strictness(
    client: TestClient, db_session: Session
) -> None:
    """Verify strict validation of StaffPartnerAssignmentStatusUpdateRequest."""
    admin = _create_user(db_session, name="Admin", mobile="9000000091", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000092", staff_id="STF-092")
    partner = _create_partner(db_session, name="Partner", mobile="9000000093")
    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()

    admin_headers = _authorization(admin)
    url = f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status"

    # 1. Empty body is rejected with 422
    empty_res = client.patch(url, headers=admin_headers, json={})
    assert empty_res.status_code == 422

    # 2. Body with old "status" field is rejected with 422 (is_active is required, extra forbidden)
    status_field_res = client.patch(url, headers=admin_headers, json={"status": "inactive"})
    assert status_field_res.status_code == 422

    # 3. Conflicting status representations are rejected with 422
    conflicting_res = client.patch(
        url,
        headers=admin_headers,
        json={"is_active": True, "status": "inactive"},
    )
    assert conflicting_res.status_code == 422

    # 4. Non-boolean string values are rejected rather than coerced (strict=True)
    for invalid_val in ["true", "false", "active", "inactive", "yes", "no"]:
        str_res = client.patch(url, headers=admin_headers, json={"is_active": invalid_val})
        assert str_res.status_code == 422, f"Failed to reject string '{invalid_val}'"

    # 5. Non-boolean integer values are rejected rather than coerced (strict=True)
    for invalid_num in [1, 0, -1]:
        num_res = client.patch(url, headers=admin_headers, json={"is_active": invalid_num})
        assert num_res.status_code == 422, f"Failed to reject number {invalid_num}"

    # 6. Valid boolean false
    valid_false_res = client.patch(url, headers=admin_headers, json={"is_active": False})
    assert valid_false_res.status_code == 200
    assert valid_false_res.json()["is_active"] is False

    # 7. Valid boolean true
    valid_true_res = client.patch(url, headers=admin_headers, json={"is_active": True})
    assert valid_true_res.status_code == 200
    assert valid_true_res.json()["is_active"] is True


def test_removed_mutation_endpoints_not_available(
    client: TestClient, db_session: Session
) -> None:
    """Verify that redundant mutation routes have been removed."""
    admin = _create_user(db_session, name="Admin", mobile="9000000101", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000102", staff_id="STF-102")
    partner = _create_partner(db_session, name="Partner", mobile="9000000103")
    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()

    admin_headers = _authorization(admin)

    # 1. POST /{assignment_id}/status -> 405 (Method Not Allowed, as only PATCH is retained)
    res_post_status = client.post(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_post_status.status_code == 405

    # 2. PATCH /{assignment_id} -> 404 or 405 (route removed)
    res_patch_bare = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_patch_bare.status_code in (404, 405)

    # 3. POST /{assignment_id}/deactivate -> 404 (route removed)
    res_post_deact = client.post(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/deactivate",
        headers=admin_headers,
    )
    assert res_post_deact.status_code == 404

    # 4. POST /{assignment_id}/reactivate -> 404 (route removed)
    res_post_react = client.post(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/reactivate",
        headers=admin_headers,
    )
    assert res_post_react.status_code == 404


def test_sqlite_uniqueness_conflict_handling_translates_to_409(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify SQLite partial unique index IntegrityError translates to HTTP 409 Conflict."""
    admin = _create_user(db_session, name="Admin", mobile="9000000111", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000112", staff_id="STF-112")
    partner = _create_partner(db_session, name="Partner", mobile="9000000113")

    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=False)
    db_session.add(assignment)
    db_session.commit()

    admin_headers = _authorization(admin)

    # Simulate SQLite partial unique constraint collision raised on commit
    def mock_commit_sqlite_unique():
        raise IntegrityError(
            "UPDATE staff_partner_assignments SET is_active = 1",
            {},
            Exception("UNIQUE constraint failed: staff_partner_assignments.staff_id, staff_partner_assignments.partner_id"),
        )

    monkeypatch.setattr(Session, "commit", lambda self: mock_commit_sqlite_unique())

    res = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res.status_code == 409
    assert res.json()["detail"] == "An active assignment already exists for this Staff-Partner pair"


def test_sqlite_uniqueness_conflict_real_partial_index(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify real SQLite partial unique index fires and is translated to HTTP 409 when race condition bypasses pre-check."""
    admin = _create_user(db_session, name="Admin", mobile="9000000121", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000122", staff_id="STF-122")
    partner = _create_partner(db_session, name="Partner", mobile="9000000123")

    assignment1 = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    assignment2 = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=False)
    db_session.add_all([assignment1, assignment2])
    db_session.commit()

    admin_headers = _authorization(admin)

    # Bypass the pre-check query by making it return None (simulating concurrent race before commit)
    original_scalar = Session.scalar

    def mocked_scalar(self, statement, *args, **kwargs):
        stmt_str = str(statement)
        if "staff_partner_assignments.id !=" in stmt_str:
            return None
        return original_scalar(self, statement, *args, **kwargs)

    monkeypatch.setattr(Session, "scalar", mocked_scalar)

    res = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment2.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res.status_code == 409
    assert res.json()["detail"] == "An active assignment already exists for this Staff-Partner pair"

    # Confirm transaction was rolled back and assignment2 is still inactive in DB
    db_session.expire_all()
    reloaded = db_session.get(StaffPartnerAssignment, assignment2.id)
    assert reloaded is not None
    assert reloaded.is_active is False


def test_unrelated_database_integrity_error_is_not_translated_to_409(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify unrelated database integrity errors are NOT translated into 409."""
    admin = _create_user(db_session, name="Admin", mobile="9000000131", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000132", staff_id="STF-132")
    partner = _create_partner(db_session, name="Partner", mobile="9000000133")

    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()

    admin_headers = _authorization(admin)

    def mock_commit_unrelated_error():
        raise IntegrityError(
            "UPDATE staff_partner_assignments",
            {},
            Exception("FOREIGN KEY constraint failed"),
        )

    monkeypatch.setattr(Session, "commit", lambda self: mock_commit_unrelated_error())

    # Should raise error and not return 409
    with pytest.raises(IntegrityError):
        client.patch(
            f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
            headers=admin_headers,
            json={"is_active": False},
        )
