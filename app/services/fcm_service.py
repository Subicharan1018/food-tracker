from firebase_admin import messaging
from app.config import logger

class FcmService:
    def _send(self, token: str, title: str, body: str, data: dict):
        if not token:
            return
        try:
            messaging.send(messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                data={str(k): str(v) for k, v in data.items()},
                token=token,
            ))
            logger.info("FCM push sent successfully to %s: %s", token[:8] + "...", title)
        except Exception as e:
            logger.error("FCM send failed: %s", e)

    def send_digest_ready(self, fcm_token: str, week: str):
        self._send(
            fcm_token,
            "Weekly Report Ready",
            f"Your recomp report for week {week} is ready.",
            {"action": "open_weekly_digest", "week": week},
        )

    def send_progression_ready(self, fcm_token: str):
        self._send(
            fcm_token,
            "Workout Plan Ready",
            "Your next week progression plan is ready.",
            {"action": "open_progression_card"},
        )

fcm_service = FcmService()
