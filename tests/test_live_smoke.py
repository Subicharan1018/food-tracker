import os
import pytest
from httpx import AsyncClient, ASGITransport
from main import app
from app.config import settings
from app.services.nemotron_service import NemotronService
from app.services.firestore_service import firestore_service

is_live = os.getenv("RUN_LIVE_TESTS") == "1"

@pytest.mark.live
@pytest.mark.skipif(not is_live, reason="Live smoke tests skipped by default. Set RUN_LIVE_TESTS=1 to run.")
@pytest.mark.asyncio
async def test_live_openrouter_complete():
    """Validates real OpenRouter API key, Nemotron model availability, and network routing."""
    if not settings.openrouter_api_key or "dummy" in settings.openrouter_api_key:
        pytest.skip("Valid OPENROUTER_API_KEY not configured in .env")

    svc = NemotronService()
    result = await svc.complete(
        system="You are a test assistant.",
        user="Reply with exactly: OK",
        max_tokens=10,
    )
    assert result is not None
    assert len(result.strip()) > 0
    print(f"\n[Live Test] Nemotron responded: {result.strip()}")

@pytest.mark.live
@pytest.mark.skipif(not is_live, reason="Live smoke tests skipped by default. Set RUN_LIVE_TESTS=1 to run.")
def test_live_firestore_connection():
    """Validates real Google Cloud Firestore connection and service account credentials."""
    if not os.path.exists(settings.google_application_credentials):
        pytest.skip(f"Service account file not found at: {settings.google_application_credentials}")

    users = firestore_service.get_all_users()
    assert isinstance(users, list)
    print(f"\n[Live Test] Connected to Firestore. Found {len(users)} user(s).")

@pytest.mark.live
@pytest.mark.skipif(not is_live, reason="Live smoke tests skipped by default. Set RUN_LIVE_TESTS=1 to run.")
@pytest.mark.asyncio
async def test_live_health_endpoint():
    """Validates FastAPI application startup and health check response with active settings."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        resp = await ac.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "model" in data
