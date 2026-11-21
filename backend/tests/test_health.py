from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_welcome_response_without_authentication() -> None:
    response = client.get("/")

    assert response.status_code == 200
    assert response.json() == {
        "message": "Welcome to Score API",
        "status": "online",
        "service": "Score App Backend",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }


def test_health_returns_ok_status() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
