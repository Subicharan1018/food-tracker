from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from app.services.digest_service import digest_service
from app.services.workout_service import workout_service
from app.config import logger

scheduler = AsyncIOScheduler()

async def _job_weekly_digests():
    logger.info("Executing scheduled Sunday weekly digests...")
    await digest_service.run_weekly_digests()

async def _job_workout_progressions():
    logger.info("Executing scheduled Friday workout progressions...")
    await workout_service.run_workout_progressions()

def start_scheduler():
    if scheduler.running:
        return
    scheduler.add_job(
        _job_weekly_digests,
        CronTrigger(day_of_week="sun", hour=6, minute=30),
        id="weekly_digest",
        replace_existing=True,
    )
    scheduler.add_job(
        _job_workout_progressions,
        CronTrigger(day_of_week="fri", hour=21, minute=0),
        id="workout_progression",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started. Jobs: weekly_digest (Sun 06:30), workout_progression (Fri 21:00)")

def shutdown_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        logger.info("Scheduler shut down cleanly.")
