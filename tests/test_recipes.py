import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from app.dependencies import get_nemotron_service, get_firestore_service

@pytest.mark.asyncio
async def test_verify_recipes_endpoint(mock_nemotron_service, mock_firestore_service):
    mock_nemotron_service.complete.return_value = (
        '[{"recipe_name":"Faulty Bar","verified":false,"discrepancy_kcal":35.0,"flag_reason":"Overstated carbs"}]'
    )
    app.dependency_overrides[get_nemotron_service] = lambda: mock_nemotron_service
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/verify-recipes", json={"user_id": "user123"})

    assert resp.status_code == 200
    flags = resp.json()["flags"]
    assert len(flags) == 1
    assert flags[0]["verified"] is False
    assert flags[0]["discrepancy_kcal"] == 35.0
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_verify_recipes_corrupted_json(mock_nemotron_service, mock_firestore_service):
    mock_nemotron_service.complete.return_value = "Broken JSON from LLM"
    app.dependency_overrides[get_nemotron_service] = lambda: mock_nemotron_service
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/verify-recipes", json={"user_id": "user123"})

    assert resp.status_code == 200
    assert resp.json()["flags"] == []
    app.dependency_overrides.clear()
