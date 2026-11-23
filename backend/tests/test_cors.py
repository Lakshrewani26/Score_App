from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.main import app

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_PRODUCTION_ORIGIN = "https://lakshrewani26.github.io"


def _require_development_environment() -> None:
    if settings.environment.lower() != "development":
        pytest.skip("Development CORS is disabled outside the development environment")


def _make_production_client(allowed_origins: list[str]) -> TestClient:
    """Return a TestClient for a minimal app configured with production CORS.

    The real ``app`` object has its middleware baked in at import time based on
    ``settings.environment``.  Tests that run in the ``development`` environment
    therefore cannot exercise the production CORS branch of ``main.py`` through
    the shared ``app``.  Instead we build a small stand-alone FastAPI instance
    that mirrors the exact production middleware configuration so we can assert
    the behaviour independently of the local environment value.
    """
    _app = FastAPI()
    _app.add_middleware(
        CORSMiddleware,
        allow_origins=allowed_origins,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Accept", "Content-Type", "Authorization"],
    )

    @_app.get("/health")
    def _health() -> dict[str, str]:
        return {"status": "ok"}

    @_app.post("/api/v1/auth/login")
    def _login() -> dict[str, str]:
        return {"access_token": "test-token", "token_type": "bearer"}

    return TestClient(_app)


def test_flutter_web_development_origin_is_allowed() -> None:
    _require_development_environment()

    origin = "http://localhost:54321"
    response = TestClient(app).get("/health", headers={"Origin": origin})

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin


def test_flutter_web_preflight_allows_catalogue_get_headers() -> None:
    _require_development_environment()

    origin = "http://127.0.0.1:61784"
    response = TestClient(app).options(
        "/api/v1/categories",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "accept,content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin
    assert "GET" in response.headers["access-control-allow-methods"]
    allowed_headers = response.headers["access-control-allow-headers"].lower()
    assert "accept" in allowed_headers
    assert "content-type" in allowed_headers
    assert "access-control-allow-credentials" not in response.headers


def test_flutter_web_preflight_allows_admin_post_and_authorization() -> None:
    _require_development_environment()

    origin = "http://localhost:50000"
    response = TestClient(app).options(
        "/api/v1/auth/admin/login",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "accept,content-type,authorization",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin
    methods = response.headers["access-control-allow-methods"]
    assert "POST" in methods
    assert "OPTIONS" in methods
    allowed_headers = response.headers["access-control-allow-headers"].lower()
    assert "authorization" in allowed_headers
    assert "content-type" in allowed_headers


# ---------------------------------------------------------------------------
# Production CORS — GitHub Pages origin
# ---------------------------------------------------------------------------


def test_production_github_pages_simple_request_is_allowed() -> None:
    """The GitHub Pages production origin must receive the ACAO header."""
    client = _make_production_client([_PRODUCTION_ORIGIN])
    response = client.get("/health", headers={"Origin": _PRODUCTION_ORIGIN})

    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == _PRODUCTION_ORIGIN


def test_production_preflight_allows_login_post() -> None:
    """OPTIONS preflight for POST /api/v1/auth/login must succeed from the
    production origin and declare POST, Content-Type, and Accept."""
    client = _make_production_client([_PRODUCTION_ORIGIN])
    response = client.options(
        "/api/v1/auth/login",
        headers={
            "Origin": _PRODUCTION_ORIGIN,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "accept,content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == _PRODUCTION_ORIGIN
    methods = response.headers.get("access-control-allow-methods", "")
    assert "POST" in methods
    assert "OPTIONS" in methods
    allowed_headers = response.headers.get("access-control-allow-headers", "").lower()
    assert "content-type" in allowed_headers
    assert "accept" in allowed_headers


def test_production_preflight_allows_authorization_header() -> None:
    """OPTIONS preflight must allow the Authorization header (needed for all
    authenticated endpoints after login)."""
    client = _make_production_client([_PRODUCTION_ORIGIN])
    response = client.options(
        "/api/v1/auth/login",
        headers={
            "Origin": _PRODUCTION_ORIGIN,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "accept,content-type,authorization",
        },
    )

    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == _PRODUCTION_ORIGIN
    allowed_headers = response.headers.get("access-control-allow-headers", "").lower()
    assert "authorization" in allowed_headers


def test_production_disallows_unrecognized_origin() -> None:
    """An origin not listed in CORS_ALLOWED_ORIGINS must NOT be reflected back.
    The ACAO header must be absent (the middleware must not echo unknown origins)."""
    client = _make_production_client([_PRODUCTION_ORIGIN])
    response = client.get(
        "/health", headers={"Origin": "https://evil.example.com"}
    )

    acao = response.headers.get("access-control-allow-origin", "")
    assert acao != "https://evil.example.com", (
        "Unknown origin must not be reflected in Access-Control-Allow-Origin"
    )


def test_production_does_not_allow_credentials() -> None:
    """The production CORS configuration must NOT set allow_credentials=True.
    Credentials mode is not required and broadening it would be a security risk."""
    client = _make_production_client([_PRODUCTION_ORIGIN])
    response = client.get("/health", headers={"Origin": _PRODUCTION_ORIGIN})

    assert response.status_code == 200
    assert (
        response.headers.get("access-control-allow-credentials", "").lower() != "true"
    )
