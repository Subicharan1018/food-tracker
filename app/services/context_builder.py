import json
from pathlib import Path
from app.config import settings
from app.services.firestore_service import firestore_service

# Pre-load and cache the recomp manual into memory once at startup
_MANUAL_CACHE: str = ""
_manual_path = Path(settings.recomp_manual_path)
if _manual_path.exists():
    try:
        _MANUAL_CACHE = _manual_path.read_text(encoding="utf-8")
    except Exception:
        _MANUAL_CACHE = ""

class ContextBuilder:
    def __init__(self, manual_text: str = None, firestore_svc=None):
        self._manual_text = manual_text if manual_text is not None else _MANUAL_CACHE
        self._fs = firestore_svc or firestore_service

    def build(
        self,
        user_id: str,
        include_diary: bool = True,
        include_workouts: bool = True,
        include_weigh_ins: bool = True,
        include_sleep: bool = False,
        diary_days: int = 30,
    ) -> str:
        profile = self._fs.get_user_profile(user_id)
        recipes = self._fs.get_recipes(user_id)

        parts = [
            "# RECOMP MANUAL v3\n" + self._manual_text,
            "\n\n# USER PROFILE\n" + json.dumps(profile, indent=2),
            "\n\n# RECIPE DATABASE\n" + self._recipes_csv(recipes),
        ]

        if include_diary:
            data = self._fs.get_diary_history(user_id, days=diary_days)
            parts.append(f"\n\n# DIARY HISTORY (last {diary_days} days)\n" + self._to_csv(data))

        if include_workouts:
            data = self._fs.get_workout_history(user_id, days=60)
            parts.append("\n\n# WORKOUT SET LOGS (last 60 days)\n" + self._to_csv(data))

        if include_weigh_ins:
            data = self._fs.get_weigh_ins(user_id, count=12)
            parts.append("\n\n# WEIGH-INS\n" + self._to_csv(data))

        if include_sleep:
            data = self._fs.get_sleep_logs(user_id, days=21)
            parts.append("\n\n# SLEEP LOGS (last 21 days)\n" + self._to_csv(data))

        return "".join(parts)

    def _recipes_csv(self, recipes: list[dict]) -> str:
        lines = ["name,mealSlot,calories,proteinG,carbsG,fatG"]
        for r in recipes:
            lines.append(
                f"{r.get('name','')},{r.get('mealSlot','')},{r.get('calories',0)},"
                f"{r.get('proteinG',0)},{r.get('carbsG',0)},{r.get('fatG',0)}"
            )
        return "\n".join(lines)

    def _to_csv(self, records: list[dict]) -> str:
        if not records:
            return "(no records)"
        keys = list(records[0].keys())
        rows = [",".join(keys)]
        for r in records:
            rows.append(",".join(str(r.get(k, "")) for k in keys))
        return "\n".join(rows)

context_builder = ContextBuilder()
