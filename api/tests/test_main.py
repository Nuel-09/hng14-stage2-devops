"""Unit tests for the FastAPI service with Redis mocked."""
from unittest.mock import MagicMock

import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture
def mock_redis(monkeypatch):
    fake = MagicMock()
    monkeypatch.setattr("main.r", fake)
    return fake


@pytest.fixture
def client(mock_redis):
    return TestClient(app)


def test_health_returns_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_job_returns_job_id_and_writes_redis(client, mock_redis):
    response = client.post("/jobs")
    assert response.status_code == 200
    body = response.json()
    assert "job_id" in body
    assert len(body["job_id"]) == 36

    mock_redis.hset.assert_called()
    mock_redis.lpush.assert_called_once_with("job", body["job_id"])


def test_get_job_returns_decoded_status(client, mock_redis):
    mock_redis.hget.return_value = b"queued"
    response = client.get("/jobs/550e8400-e29b-41d4-a716-446655440000")
    assert response.status_code == 200
    assert response.json() == {
        "job_id": "550e8400-e29b-41d4-a716-446655440000",
        "status": "queued",
    }


def test_get_job_missing_returns_404(client, mock_redis):
    mock_redis.hget.return_value = None
    response = client.get("/jobs/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404
