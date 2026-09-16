import pytest
from app.services.workout_service import WorkoutService

@pytest.mark.asyncio
async def test_workout_service_generate_progression(
    mock_nemotron_service,
    mock_context_builder,
    mock_firestore_service,
    mock_fcm_service,
):
    mock_nemotron_service.run_agent_loop.return_value = (
        '[{"name":"Barbell Squat","current":"80kg x 5","recommendation":"82.5kg x 5","reasoning":"Smooth RPE 7"}]'
    )

    svc = WorkoutService(
        nemotron_svc=mock_nemotron_service,
        context_bld=mock_context_builder,
        firestore_svc=mock_firestore_service,
        fcm_svc=mock_fcm_service,
    )

    resp = await svc.generate_workout_progression("user123")
    assert len(resp.exercises) == 1
    assert resp.exercises[0].name == "Barbell Squat"

@pytest.mark.asyncio
async def test_workout_service_run_workout_progressions(
    mock_nemotron_service,
    mock_context_builder,
    mock_firestore_service,
    mock_fcm_service,
):
    mock_firestore_service.get_all_users.return_value = [
        {"id": "u1", "fcmToken": "t1"},
    ]
    mock_nemotron_service.run_agent_loop.return_value = "[]"

    svc = WorkoutService(
        nemotron_svc=mock_nemotron_service,
        context_bld=mock_context_builder,
        firestore_svc=mock_firestore_service,
        fcm_svc=mock_fcm_service,
    )

    await svc.run_workout_progressions()
    mock_fcm_service.send_progression_ready.assert_called_once_with("t1")

@pytest.mark.asyncio
async def test_workout_service_fallback_on_error(
    mock_nemotron_service,
    mock_context_builder,
    mock_firestore_service,
    mock_fcm_service,
):
    mock_nemotron_service.run_agent_loop.side_effect = RuntimeError("Nemotron agent loop failed: 'NoneType' object is not subscriptable")
    mock_firestore_service.get_workout_history.return_value = [
        {"exerciseName": "Barbell Squat", "weightKg": 100, "reps": 5, "date": "2026-09-10"},
    ]

    svc = WorkoutService(
        nemotron_svc=mock_nemotron_service,
        context_bld=mock_context_builder,
        firestore_svc=mock_firestore_service,
        fcm_svc=mock_fcm_service,
    )

    resp = await svc.generate_workout_progression("user123")
    assert len(resp.exercises) == 6
    squat = next(e for e in resp.exercises if e.name == "Barbell Squat")
    assert "100" in squat.current
    assert "102.5" in squat.recommendation
