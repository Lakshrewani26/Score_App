from fastapi.testclient import TestClient
import pytest

from app.core.config import settings
from app.main import app


def _require_development_environment() -> None:
    if settings.environment.lower() != "development":
        pytest.skip("Development CORS is disabled outside the development environment")


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
