from __future__ import annotations

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import verify_password
from app.models import User
from scripts.create_admin import AdminProvisioningError, create_admin_user


def test_create_admin_user_success(db_session: Session) -> None:
    admin = create_admin_user(
        db=db_session,
        name="Super Admin",
        mobile="9876543210",
        password="SecureAdminPassword123!",
        password_confirm="SecureAdminPassword123!",
    )
    db_session.commit()

    saved_admin = db_session.scalars(
        select(User).where(User.mobile == "9876543210")
    ).first()

    assert saved_admin is not None
    assert saved_admin.id == admin.id
    assert saved_admin.name == "Super Admin"
    assert saved_admin.mobile == "9876543210"
    assert saved_admin.role == "admin"
    assert saved_admin.is_active is True
    # Password hash must be bcrypt and match the plaintext password
    assert saved_admin.password_hash.startswith("$2b$")
    assert verify_password("SecureAdminPassword123!", saved_admin.password_hash) is True
    assert "SecureAdminPassword123!" not in saved_admin.password_hash


def test_create_admin_rejects_duplicate_admin_mobile(db_session: Session) -> None:
    create_admin_user(
        db=db_session,
        name="First Admin",
        mobile="9876543210",
        password="Password123!",
        password_confirm="Password123!",
    )
    db_session.commit()

    with pytest.raises(AdminProvisioningError) as exc_info:
        create_admin_user(
            db=db_session,
            name="Second Admin",
            mobile="9876543210",
            password="OtherPassword123!",
            password_confirm="OtherPassword123!",
        )

    assert "already exists" in str(exc_info.value)
    assert "role='admin'" in str(exc_info.value)


@pytest.mark.parametrize("existing_role", ["customer", "partner", "staff"])
def test_create_admin_rejects_and_does_not_promote_existing_user(
    db_session: Session, existing_role: str
) -> None:
    existing_user = User(
        name=f"Existing {existing_role.capitalize()}",
        mobile="9123456789",
        password_hash="$2b$12$DummyHashExistingRole12345678901234567890",
        role=existing_role,
        is_active=True,
    )
    db_session.add(existing_user)
    db_session.commit()

    with pytest.raises(AdminProvisioningError) as exc_info:
        create_admin_user(
            db=db_session,
            name="Attempted Admin",
            mobile="9123456789",
            password="NewPassword123!",
            password_confirm="NewPassword123!",
        )

    assert "already exists" in str(exc_info.value)
    assert f"role='{existing_role}'" in str(exc_info.value)
    assert "Cannot overwrite or promote" in str(exc_info.value)

    # Verify original user was NOT promoted or modified
    db_session.refresh(existing_user)
    assert existing_user.role == existing_role
    assert existing_user.name == f"Existing {existing_role.capitalize()}"


def test_create_admin_password_confirmation_mismatch(db_session: Session) -> None:
    with pytest.raises(AdminProvisioningError) as exc_info:
        create_admin_user(
            db=db_session,
            name="Admin User",
            mobile="9876543210",
            password="Password123!",
            password_confirm="DifferentPassword123!",
        )

    assert "confirmation does not match" in str(exc_info.value)
    # Ensure no record was created
    user = db_session.scalars(select(User).where(User.mobile == "9876543210")).first()
    assert user is None


def test_create_admin_short_password(db_session: Session) -> None:
    with pytest.raises(AdminProvisioningError) as exc_info:
        create_admin_user(
            db=db_session,
            name="Admin User",
            mobile="9876543210",
            password="short",
            password_confirm="short",
        )

    assert "at least 8 characters" in str(exc_info.value)


@pytest.mark.parametrize("invalid_mobile", ["", "123", "abc", "12345678901234567"])
def test_create_admin_invalid_mobile(db_session: Session, invalid_mobile: str) -> None:
    with pytest.raises(AdminProvisioningError) as exc_info:
        create_admin_user(
            db=db_session,
            name="Admin User",
            mobile=invalid_mobile,
            password="ValidPassword123!",
            password_confirm="ValidPassword123!",
        )

    assert "Invalid mobile number" in str(exc_info.value)


def test_create_admin_empty_name(db_session: Session) -> None:
    with pytest.raises(AdminProvisioningError) as exc_info:
        create_admin_user(
            db=db_session,
            name="   ",
            mobile="9876543210",
            password="ValidPassword123!",
            password_confirm="ValidPassword123!",
        )

    assert "Name cannot be empty" in str(exc_info.value)


def test_create_admin_cli_main_success(
    test_engine, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    from scripts import create_admin

    inputs = iter(["CLI Admin", "9876543210"])
    passwords = iter(["SecurePass123!", "SecurePass123!"])

    monkeypatch.setattr("builtins.input", lambda prompt="": next(inputs))
    monkeypatch.setattr("getpass.getpass", lambda prompt="": next(passwords))
    monkeypatch.setattr(create_admin, "get_engine", lambda: test_engine)

    create_admin.main()

    captured = capsys.readouterr()
    assert "[SUCCESS] Admin account created successfully" in captured.out
    assert "CLI Admin" in captured.out
    assert "9876543210" in captured.out
    # Never leak passwords or secrets
    assert "SecurePass123!" not in captured.out
    assert "$2b$" not in captured.out


def test_create_admin_cli_main_handles_validation_error(
    test_engine, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    from scripts import create_admin

    inputs = iter(["CLI Admin", "invalid-mobile"])
    passwords = iter(["SecurePass123!", "SecurePass123!"])

    monkeypatch.setattr("builtins.input", lambda prompt="": next(inputs))
    monkeypatch.setattr("getpass.getpass", lambda prompt="": next(passwords))
    monkeypatch.setattr(create_admin, "get_engine", lambda: test_engine)

    with pytest.raises(SystemExit) as exc_info:
        create_admin.main()

    assert exc_info.value.code == 1
    captured = capsys.readouterr()
    assert "[ERROR] Provisioning failed" in captured.err

