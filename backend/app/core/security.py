from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone
from typing import Any

import bcrypt
import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import get_db
from app.models import User

# Bearer token scheme; auto_error=False to allow custom 401 handling
bearer_scheme = HTTPBearer(auto_error=False)

# Error detail returned when a session is revoked (device B invalidates device A)
SESSION_REVOKED_DETAIL = (
    "Your account was logged in on another device. Please log in again."
)


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


def generate_session_token() -> str:
    """Generate a cryptographically secure 64-hex-character session token."""
    return secrets.token_hex(32)


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


# Claims that are set by create_access_token itself and must not be overridden
# via the extra_claims argument.
_RESERVED_JWT_CLAIMS: frozenset[str] = frozenset(
    {"sub", "role", "iat", "nbf", "exp", "mobile", "sid"}
)


def create_access_token(
    subject: str,
    role: str,
    mobile: str | None = None,
    expires_delta: timedelta | None = None,
    extra_claims: dict[str, Any] | None = None,
    session_id: str | None = None,
) -> str:
    """Generate a signed expiring JWT access token.

    Args:
        subject: User ID string.
        role: User role.
        mobile: Optional mobile number.
        expires_delta: Optional token lifetime override.
        extra_claims: Optional additional JWT claims.
        session_id: Optional session token (sid claim). When provided, the backend
            will verify this claim against the stored session_token on every request,
            enforcing single-active-session per account.
    """
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
    if session_id:
        payload["sid"] = session_id
    if extra_claims:
        conflicts = sorted(extra_claims.keys() & _RESERVED_JWT_CLAIMS)
        if conflicts:
            raise ValueError(
                f"extra_claims must not override reserved JWT claims: {conflicts}"
            )
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


def _verify_session_token(payload: dict[str, Any], user: User) -> None:
    """Validate the JWT sid claim against the stored session_token.

    Strict single-session rules:
    1. If the user account has a session_token set in the database:
       The token MUST carry an 'sid' claim and it MUST match user.session_token.
       Tokens without 'sid' (legacy tokens) or with mismatched 'sid' (old devices)
       are immediately rejected with HTTP 401.
    2. If the user's session was revoked or cleared:
       Any token carrying an 'sid' is immediately rejected with HTTP 401.
    """
    sid = payload.get("sid")
    if user.session_token is not None:
        if not sid or user.session_token != sid:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=SESSION_REVOKED_DETAIL,
                headers={"WWW-Authenticate": "Bearer"},
            )
        return

    # If user.session_token is None:
    # Any token carrying a session_id claim is invalid because the session was cleared.
    if sid is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=SESSION_REVOKED_DETAIL,
            headers={"WWW-Authenticate": "Bearer"},
        )


def _resolve_user_from_token(
    credentials: HTTPAuthorizationCredentials | None,
    db: Session,
    require_role: str | None = None,
) -> tuple[User, dict[str, Any]]:
    """Shared helper: validates bearer token, loads user, checks active status.

    Returns (user, payload) on success.
    Raises HTTPException on any validation failure.
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

    # Single-session check: validate sid if present in token
    _verify_session_token(payload, user)

    if require_role is not None:
        token_role = payload.get("role")
        if token_role != require_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN if token_role else status.HTTP_401_UNAUTHORIZED,
                detail=f"{require_role.capitalize()} privileges required",
                headers={"WWW-Authenticate": "Bearer"} if not token_role else None,
            )
        if user.role != require_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"{require_role.capitalize()} privileges required",
            )

    return user, payload


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

    # Single-session check
    _verify_session_token(payload, user)

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

    # Single-session check
    _verify_session_token(payload, user)

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


def require_staff_or_admin(
    user: User = Depends(get_current_active_user),
) -> User:
    """
    Ensures that the authenticated user holds either the 'staff' or 'admin' role.
    """
    if user.role not in ("staff", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Staff or Admin privileges required",
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


def get_optional_current_active_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User | None:
    """
    Optional authentication dependency.
    If no authentication token is supplied, returns None so public catalogue access continues to work.
    If a token is supplied but is invalid, expired, malformed, or belongs to a missing/inactive user, returns HTTP 401.
    If a valid token for an active user is supplied, returns the active user.
    """
    auth_header = request.headers.get("Authorization") or request.headers.get("authorization")
    if not auth_header or not auth_header.strip():
        return None

    if credentials is None or credentials.scheme.lower() != "bearer" or not credentials.credentials.strip():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials.strip()
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
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Single-session check for optional auth too
    _verify_session_token(payload, user)

    return user
