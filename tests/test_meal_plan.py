import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from app.dependencies import get_nemotron_service, get_firestore_service

@pytest.mark.asyncio
async def test_meal_plan_endpoint(mock_nemotron_service, mock_firestore_service):
    mock_nemotron_service.run_agent_loop.return_value = (
        '```json\n[{"recipe_name":"Egg Scramble","meal_slot":"breakfast","calories":350,"protein":28,"reasoning":"High protein"}]\n```'
    )
    app.dependency_overrides[get_nemotron_service] = lambda: mock_nemotron_service
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/meal-plan", json={"user_id": "user123", "today_diary": [], "today_water_ml": 2000})

    assert resp.status_code == 200
    data = resp.json()
    assert len(data["plan"]) == 1
    assert data["plan"][0]["recipe_name"] == "Egg Scramble"
    app.dependency_overrides.clear()

@pytest.mark.asyncio
async def test_meal_plan_endpoint_corrupted_json(mock_nemotron_service, mock_firestore_service):
    # Unparseable response from Nemotron
    mock_nemotron_service.run_agent_loop.return_value = "Sorry, I cannot generate JSON right now: {broken json..."
    app.dependency_overrides[get_nemotron_service] = lambda: mock_nemotron_service
    app.dependency_overrides[get_firestore_service] = lambda: mock_firestore_service

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/meal-plan", json={"user_id": "user123", "today_diary": [], "today_water_ml": 1000})

    assert resp.status_code == 200
    data = resp.json()
    # Must defensively return empty plan and empty raw_text without crashing 500
    assert data["plan"] == []
    assert data["raw_text"] == ""
    app.dependency_overrides.clear()
