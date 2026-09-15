from unittest.mock import MagicMock
from app.services.firestore_service import FirestoreService

def test_firestore_service_read_methods_with_mock_client():
    mock_db = MagicMock()
    mock_doc = MagicMock()
    mock_doc.get().to_dict.return_value = {"name": "Test User"}
    mock_db.collection().document.return_value = mock_doc

    fs = FirestoreService(client=mock_db)
    profile = fs.get_user_profile("user1")
    assert profile == {"name": "Test User"}

def test_firestore_service_fallback_on_none_db():
    fs = FirestoreService(client=None)
    assert fs.get_user_profile("user1") == {}
    assert fs.get_all_users() == []
    assert fs.get_diary_history("user1") == []
    assert fs.get_digest("user1", "2026-W37") is None
