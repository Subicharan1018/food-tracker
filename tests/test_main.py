import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from app.dependencies import get_firestore_service

@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"

@pytest.mark.asyncio
async def test_update_fcm_token(mock_firestore_service):
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/user/fcm-token", json={"user_id": "user123", "fcm_token": "new_token"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "updated"
    mock_firestore_service.update_fcm_token.assert_called_once_with("user123", "new_token")
    app.dependency_overrides.clear()
