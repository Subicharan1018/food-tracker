import pytest
from app.services.digest_service import DigestService

@pytest.mark.asyncio
async def test_digest_service_generate_and_save(
    mock_nemotron_service,
    mock_context_builder,
    mock_firestore_service,
    mock_fcm_service,
):
    mock_nemotron_service.complete.return_value = "Excellent training consistency."

    svc = DigestService(
        nemotron_svc=mock_nemotron_service,
        context_bld=mock_context_builder,
        firestore_svc=mock_firestore_service,
        fcm_svc=mock_fcm_service,
    )

    await svc.generate_and_save("user123", "2026-W37", "fcm_token_123")
    mock_firestore_service.save_digest.assert_called_once()
    mock_fcm_service.send_digest_ready.assert_called_once_with("fcm_token_123", "2026-W37")

@pytest.mark.asyncio
async def test_digest_service_run_weekly_digests(
    mock_nemotron_service,
    mock_context_builder,
    mock_firestore_service,
    mock_fcm_service,
):
    mock_firestore_service.get_all_users.return_value = [
        {"id": "u1", "fcmToken": "t1"},
        {"id": "u2", "fcmToken": "t2"},
    ]
    svc = DigestService(
        nemotron_svc=mock_nemotron_service,
        context_bld=mock_context_builder,
        firestore_svc=mock_firestore_service,
        fcm_svc=mock_fcm_service,
    )

    await svc.run_weekly_digests()
    assert mock_firestore_service.save_digest.call_count == 2
    assert mock_fcm_service.send_digest_ready.call_count == 2
