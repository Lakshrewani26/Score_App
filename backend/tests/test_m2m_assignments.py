from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.security import create_access_token, hash_password
from app.models import (
    CustomerProfile,
    Order,
    PartnerProfile,
    StaffPartnerAssignment,
    StaffProfile,
    User,
)


def _create_user(
    db: Session,
    *,
    name: str,
    mobile: str,
    role: str,
) -> User:
    user = User(
        name=name,
        mobile=mobile,
        role=role,
        is_active=True,
        password_hash=hash_password("SecurePass123!"),
    )
    db.add(user)
    db.flush()
    return user


def _auth(user: User) -> dict[str, str]:
    token = create_access_token(subject=str(user.id), role=user.role)
    return {"Authorization": f"Bearer {token}"}


def test_m2m_multiple_staff_to_one_partner(client: TestClient, db_session: Session) -> None:
    """Admin can associate multiple Staff members to a single Partner."""
    admin = _create_user(db_session, name="Admin M2M", mobile="9800000001", role="admin")
    staff1 = _create_user(db_session, name="Staff 1", mobile="9800000002", role="staff")
    db_session.add(StaffProfile(user_id=staff1.id, staff_id="STF-M2M-01"))
    staff2 = _create_user(db_session, name="Staff 2", mobile="9800000003", role="staff")
    db_session.add(StaffProfile(user_id=staff2.id, staff_id="STF-M2M-02"))
    partner = _create_user(db_session, name="Partner MultiStaff", mobile="9800000004", role="partner")
    db_session.add(PartnerProfile(user_id=partner.id, business_name="MultiStaff Store", business_address="City"))
    db_session.commit()

    admin_headers = _auth(admin)

    # 1. Assign Staff 1 to Partner
    res1 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff1.id, "partner_id": partner.id},
    )
    assert res1.status_code == 201
    assert res1.json()["is_active"] is True

    # 2. Assign Staff 2 to Partner (both should be actively assigned under M2M)
    res2 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff2.id, "partner_id": partner.id},
    )
    assert res2.status_code == 201
    assert res2.json()["is_active"] is True

    # 3. Check active assignments list - both staff are actively assigned
    list_res = client.get(
        "/api/v1/admin/staff-partner-assignments?is_active=true",
        headers=admin_headers,
    )
    assert list_res.status_code == 200
    active_assignments = [a for a in list_res.json() if a["partner_id"] == partner.id]
    assert len(active_assignments) == 2
    assigned_staff_ids = {a["staff_id"] for a in active_assignments}
    assert assigned_staff_ids == {staff1.id, staff2.id}


def test_m2m_multiple_partners_to_one_staff(client: TestClient, db_session: Session) -> None:
    """Admin can associate multiple Partners with one Staff member."""
    admin = _create_user(db_session, name="Admin M2M 2", mobile="9800000011", role="admin")
    staff = _create_user(db_session, name="Staff Solo", mobile="9800000012", role="staff")
    db_session.add(StaffProfile(user_id=staff.id, staff_id="STF-M2M-03"))
    partner1 = _create_user(db_session, name="Partner A", mobile="9800000013", role="partner")
    db_session.add(PartnerProfile(user_id=partner1.id, business_name="Store A", business_address="City A"))
    partner2 = _create_user(db_session, name="Partner B", mobile="9800000014", role="partner")
    db_session.add(PartnerProfile(user_id=partner2.id, business_name="Store B", business_address="City B"))
    db_session.commit()

    admin_headers = _auth(admin)

    # Assign Staff to Partner 1
    res1 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner1.id},
    )
    assert res1.status_code == 201

    # Assign Staff to Partner 2
    res2 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner2.id},
    )
    assert res2.status_code == 201

    # Staff's assigned partners endpoint returns both
    staff_headers = _auth(staff)
    partners_res = client.get("/api/v1/staff/partners", headers=staff_headers)
    assert partners_res.status_code == 200
    partner_ids = {p["id"] for p in partners_res.json()}
    assert partner_ids == {partner1.id, partner2.id}


def test_m2m_duplicate_assignment_prevented(client: TestClient, db_session: Session) -> None:
    """Duplicate active assignment of the exact same (staff, partner) pair returns 409."""
    admin = _create_user(db_session, name="Admin M2M 3", mobile="9800000021", role="admin")
    staff = _create_user(db_session, name="Staff Dup", mobile="9800000022", role="staff")
    db_session.add(StaffProfile(user_id=staff.id, staff_id="STF-M2M-04"))
    partner = _create_user(db_session, name="Partner Dup", mobile="9800000023", role="partner")
    db_session.add(PartnerProfile(user_id=partner.id, business_name="Dup Store", business_address="City"))
    db_session.commit()

    admin_headers = _auth(admin)

    # First assignment succeeds
    res1 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res1.status_code == 201

    # Duplicate assignment fails with 409
    res2 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff.id, "partner_id": partner.id},
    )
    assert res2.status_code == 409
    assert "already assigned" in res2.json()["detail"].lower()


def test_m2m_deactivate_and_authorization(client: TestClient, db_session: Session) -> None:
    """Deactivating one staff's assignment does not affect another staff's assignment."""
    admin = _create_user(db_session, name="Admin M2M 4", mobile="9800000031", role="admin")
    staff1 = _create_user(db_session, name="Staff Active", mobile="9800000032", role="staff")
    db_session.add(StaffProfile(user_id=staff1.id, staff_id="STF-M2M-05"))
    staff2 = _create_user(db_session, name="Staff Deact", mobile="9800000033", role="staff")
    db_session.add(StaffProfile(user_id=staff2.id, staff_id="STF-M2M-06"))
    partner = _create_user(db_session, name="Partner Shared", mobile="9800000034", role="partner")
    db_session.add(PartnerProfile(user_id=partner.id, business_name="Shared Store", business_address="City"))
    db_session.commit()

    admin_headers = _auth(admin)

    # Assign both
    r1 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff1.id, "partner_id": partner.id},
    )
    r2 = client.post(
        "/api/v1/admin/staff-partner-assignments",
        headers=admin_headers,
        json={"staff_id": staff2.id, "partner_id": partner.id},
    )
    assignment2_id = r2.json()["id"]

    # Deactivate staff2's assignment
    deact_res = client.patch(
        f"/api/v1/admin/staff-partner-assignments/{assignment2_id}/status",
        headers=admin_headers,
        json={"is_active": False},
    )
    assert deact_res.status_code == 200
    assert deact_res.json()["is_active"] is False

    # Staff 1 still has the partner in their assigned partners
    staff1_headers = _auth(staff1)
    p1 = client.get("/api/v1/staff/partners", headers=staff1_headers).json()
    assert any(p["id"] == partner.id for p in p1)

    # Staff 2 no longer has the partner in their assigned partners
    staff2_headers = _auth(staff2)
    p2 = client.get("/api/v1/staff/partners", headers=staff2_headers).json()
    assert not any(p["id"] == partner.id for p in p2)
