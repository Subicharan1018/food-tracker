import pytest
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
from main import app
from app.dependencies import get_digest_service, get_firestore_service

@pytest.mark.asyncio
async def test_digest_trigger_and_get(mock_firestore_service):
    mock_ds = AsyncMock()
    app.dependency_overrides[get_digest_service] = lambda: mock_ds
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Trigger async digest
        post_resp = await ac.post("/ai/weekly-digest/trigger", json={"user_id": "user123", "fcm_token": "token", "week": "2026-W37"})
        assert post_resp.status_code == 200
        assert post_resp.json()["status"] == "queued"

        # Get cached digest
        get_resp = await ac.get("/ai/weekly-digest/user123/2026-W37")
        assert get_resp.status_code == 200
        assert get_resp.json()["cached"] is True
        assert get_resp.json()["content"] != ""

        # Get uncached digest
        mock_firestore_service.get_digest.return_value = None
        get_uncached = await ac.get("/ai/weekly-digest/user123/2026-W99")
        assert get_uncached.status_code == 200
        assert get_uncached.json()["cached"] is False
        assert get_uncached.json()["content"] == ""

    app.dependency_overrides.clear()
