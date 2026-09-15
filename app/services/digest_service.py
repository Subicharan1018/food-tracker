from datetime import datetime
from app.services.nemotron_service import nemotron_service, NemotronService
from app.services.context_builder import context_builder, ContextBuilder
from app.services.firestore_service import firestore_service, FirestoreService
from app.services.fcm_service import fcm_service, FcmService
from app.config import logger

DIGEST_PROMPT = (
    "Write a weekly recomp progress report for this athlete. Cover:\n"
    "1. Nutrition adherence (protein target hit X/7 days, avg deficit/surplus).\n"
    "2. Training consistency (sessions completed vs planned 4-day split).\n"
    "3. Body composition signal (weight change — noise vs real trend).\n"
    "4. Sleep quality and likely impact on recovery this week.\n"
    "5. One specific, actionable change for next week.\n"
    "Be direct. No fluff. Max 300 words. "
    "Use Recomp Manual targets (2350 kcal, 155g protein) as baseline."
)

class DigestService:
    def __init__(
        self,
        nemotron_svc: NemotronService = None,
        context_bld: ContextBuilder = None,
        firestore_svc: FirestoreService = None,
        fcm_svc: FcmService = None,
    ):
        self._nemotron = nemotron_svc or nemotron_service
        self._context_builder = context_bld or context_builder
        self._firestore = firestore_svc or firestore_service
        self._fcm = fcm_svc or fcm_service

    async def generate_and_save(self, user_id: str, week: str, fcm_token: str):
        system = self._context_builder.build(
            user_id,
            include_diary=True,
            include_workouts=True,
            include_weigh_ins=True,
            include_sleep=True,
            diary_days=7,
        )
        try:
            content = await self._nemotron.complete(system, DIGEST_PROMPT, max_tokens=1000)
        except Exception as e:
            content = f"Digest generation failed: {e}"
            logger.error("Error generating digest for user %s: %s", user_id, e)

        self._firestore.save_digest(user_id, week, {"week": week, "content": content})
        self._fcm.send_digest_ready(fcm_token, week)

    async def run_weekly_digests(self):
        week = datetime.now().strftime("%Y-W%W")
        users = self._firestore.get_all_users()
        for user in users:
            uid = user.get("id")
            token = user.get("fcmToken", "")
            if uid:
                await self.generate_and_save(uid, week, token)

digest_service = DigestService()
