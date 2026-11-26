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


def test_admin_deactivation_and_new_assignment_period(
    client: TestClient, db_session: Session
) -> None:
    # 1. Admin can deactivate an active assignment.
    # 2. Reactivating an inactive assignment is rejected (Phase 4.C).
    # 3. Reassignment creates a new assignment period (Phase 4.A).
    # 9. Deactivated assignments remain in the database with deactivation metadata.
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
    assert deactivated_data["deactivated_at"] is not None
    assert deactivated_data["deactivated_by"] == admin.id

    # 9. Verify deactivated assignment remains in database with deactivation metadata
    db_session.expire_all()
    record = db_session.get(StaffPartnerAssignment, assignment_id)
    assert record is not None
    assert record.is_active is False
    assert record.staff_id == staff.id
    assert record.partner_id == partner.id
    assert record.deactivated_at is not None
    assert record.deactivated_by == admin.id

    # 2. Reactivating old inactive assignment is rejected (Phase 4.C)
    res_reactivate = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment_id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_reactivate.status_code == 400
    assert "cannot be reactivated" in res_reactivate.json()["detail"].lower()

    # 3. Reassignment creates a new assignment period via POST
    res_new_period = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res_new_period.status_code == 201
    new_data = res_new_period.json()
    assert new_data["id"] != assignment_id
    assert new_data["is_active"] is True
    assert new_data["staff_id"] == staff.id
    assert new_data["partner_id"] == partner.id

    # 10. Verify old assignment remains unchanged and new assignment exists
    db_session.expire_all()
    old_record = db_session.get(StaffPartnerAssignment, assignment_id)
    assert old_record is not None
    assert old_record.id == assignment_id
    assert old_record.is_active is False
    assert old_record.deactivated_at is not None
    assert old_record.deactivated_by == admin.id


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


def test_repeated_deactivation_is_idempotent_and_reactivation_rejected(
    client: TestClient, db_session: Session
) -> None:
    # 6. Repeated deactivation is idempotent and preserves original metadata.
    # 7. Reactivation of an inactive assignment is rejected (Phase 4.C).
    admin = _create_user(db_session, name="Admin", mobile="9000000061", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000062", staff_id="STF-062")
    partner = _create_partner(db_session, name="Partner", mobile="9000000063")
    assignment = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment)
    db_session.commit()
    admin_headers = _authorization(admin)

    # 7. Repeated active call on already active assignment is safe and idempotent
    res_re_activate = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_re_activate.status_code == 200
    assert res_re_activate.json()["is_active"] is True

    # Deactivate once: sets deactivated_at and deactivated_by
    res_deactivate_1 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate_1.status_code == 200
    data_1 = res_deactivate_1.json()
    assert data_1["is_active"] is False
    assert data_1["deactivated_at"] is not None
    assert data_1["deactivated_by"] == admin.id
    first_deactivated_at = data_1["deactivated_at"]

    # 6. Repeated deactivation on already inactive assignment does NOT overwrite metadata
    res_deactivate_2 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate_2.status_code == 200
    data_2 = res_deactivate_2.json()
    assert data_2["is_active"] is False
    assert data_2["deactivated_at"] == first_deactivated_at
    assert data_2["deactivated_by"] == admin.id

    # Repeated deactivation remains safe and idempotent
    res_deactivate_3 = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deactivate_3.status_code == 200
    assert res_deactivate_3.json()["is_active"] is False

    # Reactivating an inactive assignment is rejected (Phase 4.C)
    res_react_rejected = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_react_rejected.status_code == 400
    assert "cannot be reactivated" in res_react_rejected.json()["detail"].lower()


def test_inactive_assignment_reactivation_always_rejected(
    client: TestClient, db_session: Session
) -> None:
    # 8. Reactivation of an inactive assignment is always rejected (Phase 4.C), regardless of whether another assignment exists.
    admin = _create_user(db_session, name="Admin", mobile="9000000071", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000072", staff_id="STF-072")
    partner = _create_partner(db_session, name="Partner", mobile="9000000073")

    assignment1 = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=False)
    assignment2 = StaffPartnerAssignment(staff_id=staff.id, partner_id=partner.id, is_active=True)
    db_session.add_all([assignment1, assignment2])
    db_session.commit()

    admin_headers = _authorization(admin)

    # Attempt to reactivate assignment1: rejected with 400
    conflict_res = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment1.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert conflict_res.status_code == 400
    assert "cannot be reactivated" in conflict_res.json()["detail"].lower()

    # Verify assignment1 is still inactive and assignment2 is still active
    db_session.expire_all()
    reloaded1 = db_session.get(StaffPartnerAssignment, assignment1.id)
    reloaded2 = db_session.get(StaffPartnerAssignment, assignment2.id)
    assert reloaded1 is not None and reloaded1.is_active is False
    assert reloaded2 is not None and reloaded2.is_active is True


def test_staff_partner_list_visibility_after_new_assignment_period(
    client: TestClient, db_session: Session
) -> None:
    # 11. Staff cannot see deactivated assignments.
    # 12. Staff can see partner again after creating a new assignment period.
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

    # 12. Reassignment via POST: creates new period, partner appears again
    res_reassign = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res_reassign.status_code == 201
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

    # 6. Valid boolean true on active assignment is safe and idempotent
    valid_true_res = client.patch(url, headers=admin_headers, json={"is_active": True})
    assert valid_true_res.status_code == 200
    assert valid_true_res.json()["is_active"] is True

    # 7. Valid boolean false deactivates
    valid_false_res = client.patch(url, headers=admin_headers, json={"is_active": False})
    assert valid_false_res.status_code == 200
    assert valid_false_res.json()["is_active"] is False

    # 8. Reactivating inactive assignment is rejected with 400
    reactivate_rejected = client.patch(url, headers=admin_headers, json={"is_active": True})
    assert reactivate_rejected.status_code == 400
    assert "cannot be reactivated" in reactivate_rejected.json()["detail"].lower()


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
    """Verify SQLite partial unique index IntegrityError translates to HTTP 409 Conflict on create."""
    admin = _create_user(db_session, name="Admin", mobile="9000000111", role="admin")
    staff = _create_staff(db_session, name="Staff", mobile="9000000112", staff_id="STF-112")
    partner = _create_partner(db_session, name="Partner", mobile="9000000113")

    admin_headers = _authorization(admin)

    # Simulate SQLite partial unique constraint collision raised on commit
    def mock_commit_sqlite_unique():
        raise IntegrityError(
            "INSERT INTO staff_partner_assignments",
            {},
            Exception("UNIQUE constraint failed: staff_partner_assignments.partner_id"),
        )

    monkeypatch.setattr(Session, "commit", lambda self: mock_commit_sqlite_unique())

    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res.status_code == 409
    assert "already has an active staff assignment" in res.json()["detail"].lower() or "already assigned" in res.json()["detail"].lower()


def test_sqlite_uniqueness_conflict_real_partial_index(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify real SQLite partial unique index fires and is translated to HTTP 409 when race condition bypasses pre-check."""
    admin = _create_user(db_session, name="Admin", mobile="9000000121", role="admin")
    staff1 = _create_staff(db_session, name="Staff 1", mobile="9000000122", staff_id="STF-122")
    partner = _create_partner(db_session, name="Partner", mobile="9000000123")

    assignment1 = StaffPartnerAssignment(staff_id=staff1.id, partner_id=partner.id, is_active=True)
    db_session.add(assignment1)
    db_session.commit()

    admin_headers = _authorization(admin)

    # Bypass the pre-check query in create_staff_partner_assignment (simulating race condition before commit)
    original_scalar = Session.scalar

    def mocked_scalar(self, statement, *args, **kwargs):
        stmt_str = str(statement)
        if "staff_partner_assignments.staff_id" in stmt_str and "staff_partner_assignments.partner_id" in stmt_str and "is_active" in stmt_str:
            return None
        return original_scalar(self, statement, *args, **kwargs)

    monkeypatch.setattr(Session, "scalar", mocked_scalar)

    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff1.id, "partner_id": partner.id},
    )
    assert res.status_code == 409
    assert "already" in res.json()["detail"].lower()


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


def test_assignment_creation_rejected_when_staff_is_inactive(
    client: TestClient, db_session: Session
) -> None:
    """Verify that assignment creation is strictly rejected with HTTP 422 if staff is inactive."""
    admin = _create_user(db_session, name="Admin", mobile="9000000201", role="admin")
    staff = _create_staff(
        db_session,
        name="Inactive Staff",
        mobile="9000000202",
        staff_id="STF-INACT-01",
        active=False,
    )
    partner = _create_partner(db_session, name="Partner One", mobile="9000000203")

    admin_headers = _authorization(admin)
    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res.status_code == 422
    assert "inactive" in res.json()["detail"].lower()
    assert "staff" in res.json()["detail"].lower()


def test_assignment_creation_rejected_when_partner_is_inactive(
    client: TestClient, db_session: Session
) -> None:
    """Verify that assignment creation is strictly rejected with HTTP 422 if partner is inactive."""
    admin = _create_user(db_session, name="Admin", mobile="9000000211", role="admin")
    staff = _create_staff(
        db_session,
        name="Active Staff",
        mobile="9000000212",
        staff_id="STF-ACT-01",
        active=True,
    )
    partner = _create_partner(
        db_session,
        name="Inactive Partner",
        mobile="9000000213",
        active=False,
    )

    admin_headers = _authorization(admin)
    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res.status_code == 422
    assert "inactive" in res.json()["detail"].lower()
    assert "partner" in res.json()["detail"].lower()


def test_staff_deactivation_closes_active_assignments_and_reactivation_safe(
    client: TestClient, db_session: Session
) -> None:
    """
    Verify that deactivating a Staff account automatically closes all active assignments
    with deactivation timestamp and deactivator admin ID, and reactivating staff does NOT reopen assignments.
    """
    admin = _create_user(db_session, name="Admin User", mobile="9000000221", role="admin")
    staff = _create_staff(db_session, name="Staff Lifecycle", mobile="9000000222", staff_id="STF-LC-01")
    partner = _create_partner(db_session, name="Partner Lifecycle", mobile="9000000223")

    admin_headers = _authorization(admin)

    # 1. Create active assignment
    res_assign = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res_assign.status_code == 201
    asgn_id = res_assign.json()["id"]

    # 2. Deactivate Staff account via status endpoint
    res_deact = client.post(
        f"/api/v1/admin/users/{staff.id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert res_deact.status_code == 200
    assert res_deact.json()["is_active"] is False

    # 3. Confirm assignment is closed in DB with audit metadata
    db_session.expire_all()
    asgn = db_session.get(StaffPartnerAssignment, asgn_id)
    assert asgn is not None
    assert asgn.is_active is False
    assert asgn.deactivated_at is not None
    assert asgn.deactivated_by == admin.id

    # 4. Reactivate Staff account
    res_react = client.post(
        f"/api/v1/admin/users/{staff.id}/status",
        headers=admin_headers,
        json={"is_active": True},
    )
    assert res_react.status_code == 200
    assert res_react.json()["is_active"] is True

    # 5. Confirm assignment remains closed
    db_session.expire_all()
    asgn_after = db_session.get(StaffPartnerAssignment, asgn_id)
    assert asgn_after is not None
    assert asgn_after.is_active is False
    assert asgn_after.deactivated_at is not None
    assert asgn_after.deactivated_by == admin.id


def test_lock_ordering_staff_user_before_partner_profile_on_postgres(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """
    Mocked lock-order test: Verifies strict lock ordering when dialect is PostgreSQL:
    1. Staff User row (SELECT ... FOR UPDATE)
    2. Partner PartnerProfile row (SELECT ... FOR UPDATE)
    Never the reverse.
    """
    admin = _create_user(db_session, name="Admin Order", mobile="9000000241", role="admin")
    staff = _create_staff(db_session, name="Staff Order", mobile="9000000242", staff_id="STF-ORD-01")
    partner = _create_partner(db_session, name="Partner Order", mobile="9000000243")

    admin_headers = _authorization(admin)

    # Force _is_postgres to return True to trigger PostgreSQL row locking branch
    from app.routers import admin as admin_router
    monkeypatch.setattr(admin_router, "_is_postgres", lambda db: True)

    locked_statements: list[str] = []
    original_scalar = Session.scalar

    def tracking_scalar(self, statement, *args, **kwargs):
        # Inspect statement for FOR UPDATE
        for_update = getattr(statement, "_for_update_arg", None)
        if for_update is not None:
            # Determine target entity
            col_descs = getattr(statement, "column_descriptions", [])
            entity_names = [str(d.get("entity", "")) for d in col_descs if "entity" in d]
            locked_statements.append(",".join(entity_names))
        return original_scalar(self, statement, *args, **kwargs)

    monkeypatch.setattr(Session, "scalar", tracking_scalar)

    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res.status_code == 201

    # Verify locked statements were captured in exact order: Staff User first, Partner PartnerProfile second
    assert len(locked_statements) == 2
    assert "User" in locked_statements[0]
    assert "PartnerProfile" in locked_statements[1]


def test_locking_not_invoked_on_sqlite(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Verify that FOR UPDATE locking is safely omitted when dialect is SQLite."""
    admin = _create_user(db_session, name="Admin SQLite", mobile="9000000251", role="admin")
    staff = _create_staff(db_session, name="Staff SQLite", mobile="9000000252", staff_id="STF-SQLITE-01")
    partner = _create_partner(db_session, name="Partner SQLite", mobile="9000000253")

    admin_headers = _authorization(admin)

    locked_statements: list[str] = []
    original_scalar = Session.scalar

    def tracking_scalar(self, statement, *args, **kwargs):
        for_update = getattr(statement, "_for_update_arg", None)
        if for_update is not None:
            locked_statements.append(str(statement))
        return original_scalar(self, statement, *args, **kwargs)

    monkeypatch.setattr(Session, "scalar", tracking_scalar)

    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res.status_code == 201
    # On SQLite, no FOR UPDATE clause should be used
    assert len(locked_statements) == 0


def test_concurrent_staff_deactivation_race_condition_rejected(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """
    Simulate the concurrency race condition:
    Admin A starts assignment creation for Staff X.
    Before the assignment is committed, Staff X is deactivated (e.g. by Admin B).
    Revalidation under the lock detects Staff X is inactive and rejects assignment creation with 422.
    """
    admin = _create_user(db_session, name="Admin Race", mobile="9000000261", role="admin")
    staff = _create_staff(db_session, name="Staff Race", mobile="9000000262", staff_id="STF-RACE-01")
    partner = _create_partner(db_session, name="Partner Race", mobile="9000000263")

    admin_headers = _authorization(admin)

    # Simulate race condition: when Staff row is selected under lock, it is found to be inactive
    original_scalar = Session.scalar

    def mock_scalar(self, statement, *args, **kwargs):
        result = original_scalar(self, statement, *args, **kwargs)
        # If querying User for staff_id, simulate that staff was deactivated concurrently
        if isinstance(result, User) and result.id == staff.id and result.role == "staff":
            result.is_active = False
        return result

    monkeypatch.setattr(Session, "scalar", mock_scalar)

    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res.status_code == 422
    assert "inactive" in res.json()["detail"].lower()

    # Verify no assignment was created in database
    db_session.expire_all()
    count = db_session.query(StaffPartnerAssignment).filter(
        StaffPartnerAssignment.staff_id == staff.id,
        StaffPartnerAssignment.partner_id == partner.id,
    ).count()
    assert count == 0


def test_missing_staff_user_does_not_proceed_to_partner_locking(
    client: TestClient,
    db_session: Session,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """
    Mocked lock-order test: Verifies that when a Staff user is missing (404),
    assignment creation aborts immediately and does NOT query or lock PartnerProfile.
    """
    admin = _create_user(db_session, name="Admin MissingStaff", mobile="9000000271", role="admin")
    partner = _create_partner(db_session, name="Partner ForMissingStaff", mobile="9000000272")
    admin_headers = _authorization(admin)

    # Force _is_postgres to return True
    from app.routers import admin as admin_router
    monkeypatch.setattr(admin_router, "_is_postgres", lambda db: True)

    queried_entities: list[str] = []
    original_scalar = Session.scalar

    def tracking_scalar(self, statement, *args, **kwargs):
        col_descs = getattr(statement, "column_descriptions", [])
        for d in col_descs:
            if "entity" in d:
                queried_entities.append(str(d["entity"]))
        return original_scalar(self, statement, *args, **kwargs)

    monkeypatch.setattr(Session, "scalar", tracking_scalar)

    res = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": 999999, "partner_id": partner.id},
    )
    assert res.status_code == 404
    assert "Staff member not found" in res.json()["detail"]

    # Assert that PartnerProfile was NEVER queried or locked
    assert any("User" in e for e in queried_entities)
    assert not any("PartnerProfile" in e for e in queried_entities)
