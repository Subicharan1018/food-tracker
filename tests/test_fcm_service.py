from unittest.mock import patch
from app.services.fcm_service import FcmService

@patch("firebase_admin.messaging.send")
def test_fcm_send_success(mock_send):
    fcm = FcmService()
    fcm.send_digest_ready("mock_token", "2026-W37")
    mock_send.assert_called_once()

@patch("firebase_admin.messaging.send", side_effect=Exception("FCM Gateway Down"))
def test_fcm_send_resilience(mock_send):
    fcm = FcmService()
    # Must not crash when FCM messaging fails
    fcm.send_progression_ready("mock_token")
    mock_send.assert_called_once()
