import pytest
from unittest.mock import patch, AsyncMock
from app.services.scheduler import _job_weekly_digests, _job_workout_progressions

@pytest.mark.asyncio
async def test_scheduler_jobs_configuration():
    # Starts inside a running loop, as FastAPI's lifespan does (APScheduler 3.11+ requires it).
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    import app.services.scheduler as sched

    fresh = AsyncIOScheduler(job_defaults=sched.scheduler._job_defaults)
    with patch.object(sched, "scheduler", fresh), \
         patch("app.services.scheduler.firestore_service.get_all_users", return_value=[]):
        sched.start_scheduler()
        job_ids = [j.id for j in fresh.get_jobs()]
        assert "weekly_digest" in job_ids
        assert "workout_progression" in job_ids
        # Double-start is a no-op.
        sched.start_scheduler()
        fresh.shutdown(wait=False)


@pytest.mark.asyncio
async def test_scheduler_jobs_execution():
    with patch("app.services.scheduler.digest_service.run_weekly_digests", new_callable=AsyncMock) as mock_digests:
        await _job_weekly_digests()
        mock_digests.assert_called_once()

    with patch("app.services.scheduler.workout_service.run_workout_progressions", new_callable=AsyncMock) as mock_prog:
        await _job_workout_progressions()
        mock_prog.assert_called_once()


@pytest.mark.asyncio
async def test_late_pacing_checks_collapse_into_one_at_the_real_hour():
    from datetime import datetime
    from app.services.scheduler import _job_pacing_check

    with patch("app.services.scheduler.firestore_service.get_all_users", return_value=[{"id": "u1"}]), \
         patch("app.services.scheduler.check_and_alert", new_callable=AsyncMock) as alert:
        woke = datetime(2026, 10, 1, 15, 5)
        await _job_pacing_check(11, now=woke)  # 14:00 is also due: skipped
        alert.assert_not_called()
        await _job_pacing_check(14, now=woke)
        assert alert.call_args.args[1] == 15


@pytest.mark.asyncio
async def test_missed_jobs_get_grace_instead_of_being_dropped():
    from apscheduler.schedulers.asyncio import AsyncIOScheduler
    import app.services.scheduler as sched

    fresh = AsyncIOScheduler(job_defaults=sched.scheduler._job_defaults)
    with patch.object(sched, "scheduler", fresh), \
         patch("app.services.scheduler.firestore_service.get_all_users", return_value=[]):
        sched.start_scheduler()
        try:
            jobs = {j.id: j for j in fresh.get_jobs()}
            assert jobs["weekly_shopping_list"].misfire_grace_time == 24 * 3600
            assert jobs["nutrition_pacing_11"].misfire_grace_time == 3 * 3600
            assert jobs["nutrition_pacing_11"].coalesce is True
            assert "shopping_list_catch_up" in jobs
        finally:
            fresh.shutdown(wait=False)
