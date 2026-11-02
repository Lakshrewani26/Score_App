from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.models import User

# Bearer token scheme; auto_error=False to allow custom 401 handling
bearer_scheme = HTTPBearer(auto_error=False)


class SecurityConfigurationError(RuntimeError):
    """Raised when critical security configuration is missing or invalid."""
    pass


def get_jwt_secret_key() -> str:
    """Return configured JWT secret key or raise a runtime error if missing."""
    key = settings.jwt_secret_key
    if not key or not key.strip():
        raise SecurityConfigurationError(
            "JWT_SECRET_KEY is not configured. Set it in the environment or backend/.env."
        )
    return key.strip()


def hash_password(password: str) -> str:
    """Hash a plaintext password using bcrypt with a generated salt."""
    if not password:
        raise ValueError("Password cannot be empty.")
    # Bcrypt accepts maximum 72 bytes
    pwd_bytes = password.encode("utf-8")[:72]
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(pwd_bytes, salt).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plaintext password against a stored bcrypt hash."""
    if not plain_password or not hashed_password:
        return False
    try:
        pwd_bytes = plain_password.encode("utf-8")[:72]
        return bcrypt.checkpw(pwd_bytes, hashed_password.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def create_access_token(
    subject: str,
    role: str,
    mobile: str | None = None,
    expires_delta: timedelta | None = None,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    """Generate a signed expiring JWT access token."""
    secret_key = get_jwt_secret_key()
    now = datetime.now(timezone.utc)
    if expires_delta:
        expire = now + expires_delta
    else:
        expire = now + timedelta(minutes=settings.jwt_access_token_expire_minutes)

    payload: dict[str, Any] = {
        "sub": str(subject),
        "role": role,
        "iat": now,
        "nbf": now,
        "exp": expire,
    }
    if mobile:
        payload["mobile"] = mobile
    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(payload, secret_key, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> dict[str, Any]:
    """Decode and validate a JWT access token, verifying signature and expiry."""
    secret_key = get_jwt_secret_key()
    return jwt.decode(
        token,
        secret_key,
        algorithms=[settings.jwt_algorithm],
        options={"require": ["exp", "sub", "role"]},
    )


def require_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """
    Reusable FastAPI dependency that validates the bearer token and confirms
    that the user account exists, remains active, and holds the 'admin' role.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided or are invalid",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str = payload.get("sub")
    token_role = payload.get("role")

    if not user_id_str or token_role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN if token_role and token_role != "admin" else status.HTTP_401_UNAUTHORIZED,
            detail="Admin privileges required" if token_role and token_role != "admin" else "Invalid authentication token payload",
            headers={"WWW-Authenticate": "Bearer"} if not (token_role and token_role != "admin") else None,
        )

    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account no longer exists",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required",
        )

    return user


def get_current_active_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    """
    Reusable FastAPI dependency that validates the bearer token and confirms
    that the user account exists and remains active.
    """
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided or are invalid",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = decode_access_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id_str = payload.get("sub")
    if not user_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        user_id = int(user_id_str)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account no longer exists",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    return user


def require_customer(
    user: User = Depends(get_current_active_user),
) -> User:
    """Ensures that the authenticated user holds the 'customer' role."""
    if user.role != "customer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Customer privileges required",
        )
    return user


def require_partner(
    user: User = Depends(get_current_active_user),
) -> User:
    """
    Ensures that the authenticated user holds the 'partner' role.
    """
    if user.role != "partner":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Partner privileges required",
        )
    return user


def require_staff(
    user: User = Depends(get_current_active_user),
) -> User:
    """Ensures that the authenticated user holds the 'staff' role."""
    if user.role != "staff":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff privileges required",
        )
    return user


def require_partner_or_staff_or_admin(
    user: User = Depends(get_current_active_user),
) -> User:
    """
    Ensures that the authenticated user is either a partner, staff, or admin.
    """
    if user.role not in ("partner", "staff", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Authorized access required",
        )
    return user
