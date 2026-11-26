from __future__ import annotations

from datetime import timedelta
import pytest

from app.core.config import Settings
from app.core.security import (
    SecurityConfigurationError,
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
)


def test_hash_password_produces_bcrypt_hash() -> None:
    hashed = hash_password("MySecurePassword123!")
    assert hashed.startswith("$2b$")
    assert verify_password("MySecurePassword123!", hashed) is True
    assert verify_password("WrongPassword!", hashed) is False


def test_hash_password_rejects_empty() -> None:
    with pytest.raises(ValueError):
        hash_password("")


def test_verify_password_handles_edge_cases() -> None:
    assert verify_password("", "$2b$12$somehashvalue") is False
    assert verify_password("password", "") is False
    assert verify_password("password", "invalid_non_bcrypt_string") is False


def test_hash_and_verify_long_password() -> None:
    long_pass = "A" * 200
    hashed = hash_password(long_pass)
    assert verify_password(long_pass, hashed) is True
    assert verify_password("wrong", hashed) is False


def test_create_and_decode_access_token() -> None:
    token = create_access_token(
        subject="42",
        role="admin",
        mobile="9876543210",
        expires_delta=timedelta(minutes=15),
    )
    payload = decode_access_token(token)
    assert payload["sub"] == "42"
    assert payload["role"] == "admin"
    assert payload["mobile"] == "9876543210"
    assert "exp" in payload


def test_missing_secret_key_raises_error(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.core.config import settings

    monkeypatch.setattr(settings, "jwt_secret_key", None)
    with pytest.raises(SecurityConfigurationError):
        create_access_token(subject="1", role="admin")


def test_production_settings_validation() -> None:
    # Fails if JWT_SECRET_KEY is missing in production
    with pytest.raises(ValueError, match="JWT_SECRET_KEY is required"):
        Settings(environment="production", jwt_secret_key=None)

    # Fails if JWT_SECRET_KEY is too short in production (< 32 chars)
    with pytest.raises(ValueError, match="at least 32 characters long"):
        Settings(environment="production", jwt_secret_key="too-short-secret")

    # Succeeds with a strong key in production
    valid_settings = Settings(
        environment="production",
        jwt_secret_key="a" * 32,
    )
    assert valid_settings.jwt_secret_key == "a" * 32


# ---------------------------------------------------------------------------
# JWT extra_claims hardening tests
# ---------------------------------------------------------------------------


def test_extra_claims_custom_claim_included_in_token() -> None:
    """A legitimate custom claim should survive encode/decode unchanged."""
    token = create_access_token(
        subject="99",
        role="customer",
        expires_delta=timedelta(minutes=5),
        extra_claims={"tenant_id": "acme-corp"},
    )
    payload = decode_access_token(token)
    assert payload["tenant_id"] == "acme-corp"
    # Core claims still intact
    assert payload["sub"] == "99"
    assert payload["role"] == "customer"


def test_extra_claims_rejects_override_of_sub() -> None:
    """Attempting to override 'sub' via extra_claims must raise ValueError."""
    with pytest.raises(ValueError, match="sub"):
        create_access_token(
            subject="1",
            role="admin",
            extra_claims={"sub": "attacker"},
        )


def test_extra_claims_rejects_override_of_role() -> None:
    """Attempting to override 'role' via extra_claims must raise ValueError."""
    with pytest.raises(ValueError, match="role"):
        create_access_token(
            subject="1",
            role="customer",
            extra_claims={"role": "admin"},
        )


def test_extra_claims_rejects_override_of_exp() -> None:
    """Attempting to override 'exp' via extra_claims must raise ValueError."""
    with pytest.raises(ValueError, match="exp"):
        create_access_token(
            subject="1",
            role="admin",
            extra_claims={"exp": 9999999999},
        )


def test_extra_claims_rejects_override_of_sid() -> None:
    """Attempting to override 'sid' via extra_claims must raise ValueError."""
    with pytest.raises(ValueError, match="sid"):
        create_access_token(
            subject="1",
            role="admin",
            extra_claims={"sid": "fake-session"},
        )


def test_extra_claims_rejects_multiple_reserved_claims() -> None:
    """When multiple reserved claims conflict, all are listed in the error."""
    with pytest.raises(ValueError) as exc_info:
        create_access_token(
            subject="1",
            role="admin",
            extra_claims={"sub": "x", "exp": 0, "tenant_id": "ok"},
        )
    error_message = str(exc_info.value)
    assert "sub" in error_message
    assert "exp" in error_message
    # The legitimate custom claim must NOT appear in the error
    assert "tenant_id" not in error_message
