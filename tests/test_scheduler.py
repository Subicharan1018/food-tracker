import pytest
from unittest.mock import patch, AsyncMock
from app.services.scheduler import scheduler, start_scheduler, shutdown_scheduler, _job_weekly_digests, _job_workout_progressions

def test_scheduler_jobs_configuration():
    start_scheduler()
    jobs = scheduler.get_jobs()
    job_ids = [j.id for j in jobs]
    assert "weekly_digest" in job_ids
    assert "workout_progression" in job_ids
    
    # Verify idempotence and double-start safety
    start_scheduler()
    shutdown_scheduler()

@pytest.mark.asyncio
async def test_scheduler_jobs_execution():
    with patch("app.services.scheduler.digest_service.run_weekly_digests", new_callable=AsyncMock) as mock_digests:
        await _job_weekly_digests()
        mock_digests.assert_called_once()

    with patch("app.services.scheduler.workout_service.run_workout_progressions", new_callable=AsyncMock) as mock_prog:
        await _job_workout_progressions()
        mock_prog.assert_called_once()
