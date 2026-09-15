import json
from app.models.responses import WorkoutProgressionResponse, ExerciseProgression
from app.services.nemotron_service import nemotron_service, NemotronService
from app.services.context_builder import context_builder, ContextBuilder
from app.services.firestore_service import firestore_service, FirestoreService
from app.services.fcm_service import fcm_service, FcmService
from app.tools.tool_registry import TOOL_SCHEMAS, make_dispatcher
from app.config import logger

COMPOUND_LIFTS = [
    "Barbell Squat", "Bench Press", "Pull-ups",
    "Overhead Press", "Romanian Deadlift", "Goblet Squat",
]

class WorkoutService:
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

    async def generate_workout_progression(self, user_id: str) -> WorkoutProgressionResponse:
        system = self._context_builder.build(user_id, include_diary=False, include_sleep=False)
        profile = self._firestore.get_user_profile(user_id)
        weigh_ins = self._firestore.get_weigh_ins(user_id)
        workout_logs = self._firestore.get_workout_history(user_id)
        dispatcher = make_dispatcher([], [], weigh_ins, workout_logs, profile)

        user_msg = (
            f"Use get_workout_trend for each of these exercises: {COMPOUND_LIFTS}.\n"
            "Use get_adherence_flags to check for plateau or stall.\n"
            "Return ONLY a JSON array: "
            '[{"name":"...","current":"...","recommendation":"...","reasoning":"..."}]'
        )

        try:
            raw = await self._nemotron.run_agent_loop(system, user_msg, TOOL_SCHEMAS, dispatcher)
            clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
            parsed = json.loads(clean)
            exercises = parsed if isinstance(parsed, list) else parsed.get("exercises", [])
            result = [ExerciseProgression(**e) for e in exercises]
        except Exception as e:
            logger.error("Workout progression generation failed for user %s: %s", user_id, e)
            result = []
            raw = ""

        return WorkoutProgressionResponse(exercises=result, raw_text=raw)

    async def run_workout_progressions(self):
        users = self._firestore.get_all_users()
        for user in users:
            uid = user.get("id")
            token = user.get("fcmToken", "")
            if not uid:
                continue
            await self.generate_workout_progression(uid)
            self._fcm.send_progression_ready(token)

workout_service = WorkoutService()
