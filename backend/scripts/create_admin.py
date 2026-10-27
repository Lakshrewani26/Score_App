from __future__ import annotations

import getpass
import re
import sys
from pathlib import Path

# Add backend directory to sys.path so imports work when executed directly
ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.session import get_engine
from app.models import User

# Mobile validation: 10 to 15 digits, optional leading '+'
MOBILE_REGEX = re.compile(r"^\+?[0-9]{10,15}$")
MIN_PASSWORD_LENGTH = 8


class AdminProvisioningError(Exception):
    """Raised when admin provisioning validation fails."""
    pass


def validate_admin_input(
    name: str,
    mobile: str,
    password: str,
    password_confirm: str,
) -> tuple[str, str, str]:
    """Validate administrative credentials and inputs."""
    cleaned_name = name.strip()
    cleaned_mobile = mobile.strip()

    if not cleaned_name:
        raise AdminProvisioningError("Name cannot be empty.")
    if len(cleaned_name) > 150:
        raise AdminProvisioningError("Name cannot exceed 150 characters.")

    if not cleaned_mobile or not MOBILE_REGEX.match(cleaned_mobile):
        raise AdminProvisioningError(
            "Invalid mobile number. Must contain 10 to 15 digits (optional leading '+')."
        )

    if not password:
        raise AdminProvisioningError("Password cannot be empty.")
    if len(password) < MIN_PASSWORD_LENGTH:
        raise AdminProvisioningError(
            f"Password must be at least {MIN_PASSWORD_LENGTH} characters long."
        )

    if password != password_confirm:
        raise AdminProvisioningError("Password confirmation does not match.")

    return cleaned_name, cleaned_mobile, password


def create_admin_user(
    db: Session,
    name: str,
    mobile: str,
    password: str,
    password_confirm: str,
) -> User:
    """
    Safely create an initial admin account within the current database session.
    Rejects duplicate mobile numbers and refuses to promote or overwrite existing accounts.
    Stores only the password hash.
    """
    cleaned_name, cleaned_mobile, valid_password = validate_admin_input(
        name=name,
        mobile=mobile,
        password=password,
        password_confirm=password_confirm,
    )

    # Check for existing user with this mobile
    existing_user = db.scalars(
        select(User).where(User.mobile == cleaned_mobile)
    ).first()

    if existing_user is not None:
        raise AdminProvisioningError(
            f"A user with mobile '{cleaned_mobile}' already exists (role='{existing_user.role}'). "
            "Cannot overwrite or promote an existing account."
        )

    pwd_hash = hash_password(valid_password)

    new_admin = User(
        name=cleaned_name,
        mobile=cleaned_mobile,
        password_hash=pwd_hash,
        role="admin",
        is_active=True,
    )

    db.add(new_admin)
    db.flush()
    return new_admin


def main() -> None:
    print("=== Score_App Initial Admin Provisioning ===")
    try:
        name = input("Enter Admin Full Name: ")
        mobile = input("Enter Admin Mobile Number: ")
        password = getpass.getpass("Enter Admin Password: ")
        password_confirm = getpass.getpass("Confirm Admin Password: ")

        engine = get_engine()
        with Session(engine) as session:
            with session.begin():
                admin = create_admin_user(
                    db=session,
                    name=name,
                    mobile=mobile,
                    password=password,
                    password_confirm=password_confirm,
                )
                admin_id = admin.id
                admin_name = admin.name
                admin_mobile = admin.mobile

        print("\n[SUCCESS] Admin account created successfully.")
        print(f"ID:     {admin_id}")
        print(f"Name:   {admin_name}")
        print(f"Mobile: {admin_mobile}")
        print("Role:   admin")
        print("Status: active")
    except AdminProvisioningError as err:
        print(f"\n[ERROR] Provisioning failed: {err}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n[INFO] Provisioning cancelled by user.", file=sys.stderr)
        sys.exit(130)
    except Exception as err:
        print(f"\n[ERROR] Unexpected error during admin provisioning: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
