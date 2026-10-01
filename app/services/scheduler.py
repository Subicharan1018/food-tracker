from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from app.services.digest_service import digest_service
from app.services.workout_service import workout_service
from app.services.firestore_service import firestore_service
from app.services.fcm_service import fcm_service
from app.services.nemotron_service import nemotron_service
from app.routers.pacing import check_and_alert
from app.services.food_db_service import food_db_service
from app.services.shopping_list_service import build_weekly_shopping_list
from app.config import logger

scheduler = AsyncIOScheduler()

async def _job_weekly_digests():
    logger.info("Executing scheduled Sunday weekly digests...")
    await digest_service.run_weekly_digests()

async def _job_workout_progressions():
    logger.info("Executing scheduled Friday workout progressions...")
    await workout_service.run_workout_progressions()

async def _job_pacing_check(hour: int):
    logger.info("Executing nutrition pacing check for %s:00...", hour)
    for user in firestore_service.get_all_users():
        user_id = user.get("id")
        if user_id:
            await check_and_alert(user_id, hour, firestore_service, fcm_service, nemotron_service)

async def _job_weekly_shopping_list():
    """Saturday 8 AM — regenerate shopping list and structural gaps for every user."""
    logger.info("Executing Saturday weekly shopping list generation...")
    for user in firestore_service.get_all_users():
        user_id = user.get("id")
        if not user_id:
            continue
        try:
            payload = await build_weekly_shopping_list(
                user_id, firestore_service, food_db_service, nemotron_service
            )
            logger.info("Shopping list saved for user %s (week %s)", user_id, payload["week"])
        except Exception as e:
            logger.error("Shopping list job failed for user %s: %s", user_id, e)

def start_scheduler():
    if scheduler.running:
        return
    scheduler.add_job(
        _job_weekly_digests,
        CronTrigger(day_of_week="sun", hour=6, minute=30),
        id="weekly_digest",
        replace_existing=True,
    )
    for hour in (11, 14, 17, 21):
        scheduler.add_job(
            _job_pacing_check,
            CronTrigger(hour=hour, minute=0),
            args=[hour],
            id=f"nutrition_pacing_{hour}",
            replace_existing=True,
        )
    scheduler.add_job(
        _job_weekly_shopping_list,
        CronTrigger(day_of_week="sat", hour=8, minute=0),
        id="weekly_shopping_list",
        replace_existing=True,
    )
    scheduler.add_job(
        _job_workout_progressions,
        CronTrigger(day_of_week="fri", hour=21, minute=0),
        id="workout_progression",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Scheduler started with weekly digest, shopping list, progression, and 11/14/17/21 nutrition pacing jobs")

def shutdown_scheduler():
    if scheduler.running:
        scheduler.shutdown()
        logger.info("Scheduler shut down cleanly.")
