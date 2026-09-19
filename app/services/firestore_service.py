import os
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore as fs
from app.config import settings, logger

# Initialize Firebase Admin singleton defensively
if not firebase_admin._apps:
    if os.path.exists(settings.google_application_credentials):
        try:
            cred = credentials.Certificate(settings.google_application_credentials)
            firebase_admin.initialize_app(cred, {"projectId": settings.firebase_project_id})
        except Exception as e:
            logger.warning("Firebase Admin certificate init failed: %s", e)
    else:
        try:
            firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})
        except Exception as e:
            logger.warning("Firebase Admin default init fallback: %s", e)

_db_client = None
_db_client_initialized = False


def _get_db_client():
    """Lazily initialize the Firestore client to avoid blocking the GCE metadata
    ping at import time when running locally without a service-account.json."""
    global _db_client, _db_client_initialized
    if _db_client_initialized:
        return _db_client
    _db_client_initialized = True
    try:
        _db_client = fs.client()
    except Exception as exc:
        logger.warning("Firestore client init failed (will run without Firestore): %s", exc)
        _db_client = None
    return _db_client

class FirestoreService:
    def __init__(self, client=None):
        self._db = client

    @property
    def db(self):
        return self._db if self._db is not None else _get_db_client()

    # ── reads ────────────────────────────────────────────────────────

    def get_user_profile(self, user_id: str) -> dict:
        if not self.db:
            return {}
        doc = self.db.collection("users").document(user_id).get()
        return doc.to_dict() or {}

    def get_all_users(self) -> list[dict]:
        if not self.db:
            return []
        docs = self.db.collection("users").stream()
        return [{"id": doc.id, **doc.to_dict()} for doc in docs]

    def get_diary_history(self, user_id: str, days: int = 30) -> list[dict]:
        if not self.db:
            return []
        cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        docs = (
            self.db.collection("users").document(user_id)
            .collection("diary_entries")
            .where("date", ">=", cutoff)
            .order_by("date", direction=fs.Query.DESCENDING)
            .stream()
        )
        return [doc.to_dict() for doc in docs]

    def get_workout_history(self, user_id: str, days: int = 60) -> list[dict]:
        if not self.db:
            return []
        cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        docs = (
            self.db.collection("users").document(user_id)
            .collection("workout_set_logs")
            .where("date", ">=", cutoff)
            .stream()
        )
        return [doc.to_dict() for doc in docs]

    def get_weigh_ins(self, user_id: str, count: int = 12) -> list[dict]:
        if not self.db:
            return []
        docs = (
            self.db.collection("users").document(user_id)
            .collection("weigh_ins")
            .order_by("date", direction=fs.Query.DESCENDING)
            .limit(count)
            .stream()
        )
        return [doc.to_dict() for doc in docs]

    def get_sleep_logs(self, user_id: str, days: int = 21) -> list[dict]:
        if not self.db:
            return []
        cutoff = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
        docs = (
            self.db.collection("users").document(user_id)
            .collection("sleep_logs")
            .where("date", ">=", cutoff)
            .stream()
        )
        return [doc.to_dict() for doc in docs]

    def get_recipes(self, user_id: str) -> list[dict]:
        if not self.db:
            return []
        docs = (
            self.db.collection("users").document(user_id)
            .collection("recipes")
            .stream()
        )
        return [{**(doc.to_dict() or {}), "id": doc.id} for doc in docs]

    def get_inventory(self, user_id: str) -> list[dict]:
        if not self.db:
            return []
        docs = self.db.collection("users").document(user_id).collection("inventory").stream()
        return [{**(doc.to_dict() or {}), "id": doc.id} for doc in docs]

    # ── writes ───────────────────────────────────────────────────────

    def save_digest(self, user_id: str, week: str, content: dict):
        if not self.db:
            return
        self.db.collection("users").document(user_id) \
            .collection("ai_digests").document(week) \
            .set({**content, "generatedAt": datetime.now().isoformat()})

    def get_digest(self, user_id: str, week: str) -> dict | None:
        if not self.db:
            return None
        doc = self.db.collection("users").document(user_id) \
            .collection("ai_digests").document(week).get()
        return doc.to_dict() if doc.exists else None

    def update_fcm_token(self, user_id: str, fcm_token: str):
        if not self.db:
            return
        self.db.collection("users").document(user_id).update({"fcmToken": fcm_token})

    def save_recipe(self, user_id: str, recipe_id: str, recipe: dict) -> bool:
        """Upsert a recipe in the user's collection using the app's sync schema."""
        if not self.db:
            return False
        payload = {**recipe, "id": recipe_id}
        (
            self.db.collection("users")
            .document(user_id)
            .collection("recipes")
            .document(recipe_id)
            .set(payload)
        )
        return True

    def update_recipe_nutrients(self, user_id: str, recipe_id: str, nutrients: dict) -> bool:
        if not self.db or not recipe_id:
            return False
        self.db.collection("users").document(user_id).collection("recipes").document(recipe_id).set(
            {"nutrients": nutrients, "nutrientsUpdatedAt": datetime.now().isoformat()}, merge=True
        )
        return True

    def save_daily_pace_status(self, user_id: str, content: dict, date_key: str | None = None) -> bool:
        if not self.db:
            return False
        date_key = date_key or datetime.now().strftime("%Y-%m-%d")
        self.db.collection("users").document(user_id).collection("daily_pace_status").document(date_key).set(
            {**content, "updated_at": datetime.now().isoformat()}, merge=True
        )
        return True

    def get_daily_pace_status(self, user_id: str, date_key: str | None = None) -> dict | None:
        if not self.db:
            return None
        date_key = date_key or datetime.now().strftime("%Y-%m-%d")
        doc = self.db.collection("users").document(user_id).collection("daily_pace_status").document(date_key).get()
        return doc.to_dict() if doc.exists else None

firestore_service = FirestoreService()
