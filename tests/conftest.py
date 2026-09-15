import pytest
from unittest.mock import MagicMock, AsyncMock
from app.services.firestore_service import FirestoreService
from app.services.nemotron_service import NemotronService
from app.services.fcm_service import FcmService
from app.services.context_builder import ContextBuilder

@pytest.fixture
def mock_firestore_service():
    svc = MagicMock(spec=FirestoreService)
    svc.get_user_profile.return_value = {
        "id": "user123",
        "name": "Subi",
        "calorieTarget": 2400,
        "proteinTarget": 160,
        "carbTarget": 250,
        "fatTarget": 70,
        "fiberTarget": 35,
        "fcmToken": "mock_fcm_token_123",
    }
    svc.get_all_users.return_value = [
        {"id": "user123", "fcmToken": "mock_fcm_token_123"}
    ]
    svc.get_recipes.return_value = [
        {"name": "Paneer Tikka", "mealSlot": "dinner", "calories": 400, "proteinG": 30, "carbsG": 10, "fatG": 20},
        {"name": "Greek Yogurt Snack", "mealSlot": "snack", "calories": 180, "proteinG": 20, "carbsG": 10, "fatG": 2},
    ]
    svc.get_diary_history.return_value = []
    svc.get_workout_history.return_value = []
    svc.get_weigh_ins.return_value = [
        {"date": "2026-09-01", "weightKg": 75.0},
        {"date": "2026-09-08", "weightKg": 74.8},
        {"date": "2026-09-15", "weightKg": 74.9},
    ]
    svc.get_sleep_logs.return_value = []
    svc.get_digest.return_value = {"week": "2026-W37", "content": "Great consistency this week."}
    return svc

@pytest.fixture
def mock_nemotron_service():
    svc = MagicMock(spec=NemotronService)
    svc.complete = AsyncMock(return_value="OK")
    svc.run_agent_loop = AsyncMock(return_value="[]")
    return svc

@pytest.fixture
def mock_fcm_service():
    svc = MagicMock(spec=FcmService)
    svc._send = MagicMock()
    svc.send_digest_ready = MagicMock()
    svc.send_progression_ready = MagicMock()
    return svc

@pytest.fixture
def mock_context_builder(mock_firestore_service):
    return ContextBuilder(manual_text="Test Recomp Manual Header", firestore_svc=mock_firestore_service)
