import pytest
from unittest.mock import AsyncMock
from httpx import AsyncClient, ASGITransport
from main import app
from app.dependencies import get_workout_service
from app.models.responses import WorkoutProgressionResponse, ExerciseProgression

@pytest.mark.asyncio
async def test_workout_progression_endpoint():
    mock_ws = AsyncMock()
    mock_ws.generate_workout_progression.return_value = WorkoutProgressionResponse(
        exercises=[ExerciseProgression(name="Bench Press", current="70kg", recommendation="72.5kg", reasoning="Good speed")],
        raw_text="[]",
    )
    app.dependency_overrides[get_workout_service] = lambda: mock_ws

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.post("/ai/workout-progression", json={"user_id": "user123"})

    assert resp.status_code == 200
    assert resp.json()["exercises"][0]["name"] == "Bench Press"
    app.dependency_overrides.clear()
