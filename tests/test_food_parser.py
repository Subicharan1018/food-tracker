import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from app.dependencies import get_nemotron_service, get_firestore_service

@pytest.mark.asyncio
async def test_food_parser_endpoint(mock_nemotron_service, mock_firestore_service):
    mock_nemotron_service.complete.return_value = (
        '[{"food_name":"Greek Yogurt Snack","portion_qty":1.0,"meal_slot":"snack"}]'
    )
    app.dependency_overrides[get_nemotron_service] = lambda: mock_nemotron_service
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/parse-food", json={"user_id": "user123", "input": "had one greek yogurt"})

    assert resp.status_code == 200
    assert resp.json()["items"][0]["food_name"] == "Greek Yogurt Snack"
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_food_parser_corrupted_json(mock_nemotron_service, mock_firestore_service):
    mock_nemotron_service.complete.return_value = "Unparseable response text"
    app.dependency_overrides[get_nemotron_service] = lambda: mock_nemotron_service
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/parse-food", json={"user_id": "user123", "input": "some food"})

    assert resp.status_code == 200
    assert resp.json()["items"] == []
    assert resp.json()["raw_text"] == ""
    app.dependency_overrides.clear()
