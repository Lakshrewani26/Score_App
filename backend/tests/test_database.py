from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from app import main
from app.core.config import settings
from app.db import session


client = TestClient(main.app)


def test_database_readiness_returns_ok_after_successful_check(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(main, "check_database_connection", lambda: None)

    response = client.get("/ready/database")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_database_readiness_returns_service_unavailable_when_not_configured(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def raise_not_configured() -> None:
        raise session.DatabaseNotConfiguredError("DATABASE_URL is not configured.")

    monkeypatch.setattr(main, "check_database_connection", raise_not_configured)

    response = client.get("/ready/database")

    assert response.status_code == 503
    assert response.json() == {"detail": "Database is unavailable"}


def test_database_check_executes_select_one(monkeypatch: pytest.MonkeyPatch) -> None:
    connection = MagicMock()
    connection.execute.return_value.scalar_one.return_value = 1
    engine = MagicMock()
    engine.connect.return_value.__enter__.return_value = connection
    engine.connect.return_value.__exit__.return_value = None
    monkeypatch.setattr(session, "get_engine", lambda: engine)

    session.check_database_connection()

    connection.execute.assert_called_once()


@pytest.mark.skipif(
    not settings.database_url,
    reason="Set DATABASE_URL to run the PostgreSQL integration check.",
)
def test_database_connectivity_when_configured() -> None:
    session.check_database_connection()
