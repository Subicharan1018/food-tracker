"""Pacing status API and scheduled alert orchestration."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.dependencies import get_fcm_service, get_firestore_service, get_nemotron_service
from app.services.fcm_service import FcmService
from app.services.firestore_service import FirestoreService
from app.services.food_db_service import food_db_service
from app.services.nemotron_service import NemotronService
from app.services.nutrient_calculator import load_nutrient_profiles
from app.services.nutrient_coverage_service import find_candidate_recipe
from app.services.pacing_service import detect_gaps, diary_micronutrients, gap_priority
from app.services.shopping_list_service import prose_is_number_free

router = APIRouter()


class PacingCheckRequest(BaseModel):
    user_id: str = Field(min_length=1)
    hour: int | None = Field(default=None, ge=0, le=23)


async def check_and_alert(
    user_id: str,
    hour: int,
    firestore: FirestoreService,
    fcm: FcmService,
    nemotron: NemotronService,
    food_db=food_db_service,
) -> dict:
    diary = firestore.get_diary_history(user_id, days=1)
    today = datetime.now().strftime("%Y-%m-%d")
    diary = [entry for entry in diary if entry.get("date") == today]
    recipes = firestore.get_recipes(user_id)
    profile = firestore.get_user_profile(user_id)
    issues = detect_gaps(diary, recipes, hour, float(profile.get("proteinTargetG") or 155.0), food_db)
    micros = diary_micronutrients(diary, recipes, food_db)
    status: dict = {
        "issues": issues,
        "checkpoint_hour": hour,
        "candidate_recipe": None,
        # Logged foods with no cited source or no known weight: shown, not zeroed.
        "uncounted_foods": sorted(set(micros["uncounted"])),
    }
    if not issues:
        firestore.save_daily_pace_status(user_id, status)
        return status

    inventory = firestore.get_inventory(user_id)
    candidate = None
    if issues.get("nutrient_gaps"):
        candidate = find_candidate_recipe(
            gap_priority(issues["nutrient_gaps"]), recipes, inventory, load_nutrient_profiles(), food_db
        )
    status["candidate_recipe"] = candidate

    # An AI call is made only after the deterministic gap calculation above,
    # and may only talk about the pre-computed candidate recipe.
    message = await _coach_message(nemotron, issues, candidate)
    status["message"] = message
    firestore.save_daily_pace_status(user_id, status)
    token = profile.get("fcmToken")
    if token:
        fcm.send_pacing_alert(token, message)
    return status


def _fallback_message(issues: dict, candidate: dict | None) -> str:
    if candidate and candidate.get("makeable"):
        return f"You can make {candidate['name']} with what's in your pantry — it closes today's biggest gap."
    if candidate:
        return f"{candidate['name']} would close today's biggest gap — it's in your cart suggestions."
    if issues.get("missed_logging"):
        return "Nothing logged yet today — log your next meal so Kinetik can track your pace."
    return "Log your next meal so Kinetik can update your nutrient pace."


async def _coach_message(nemotron: NemotronService, issues: dict, candidate: dict | None) -> str:
    fallback = _fallback_message(issues, candidate)
    behind = sorted(issues.get("nutrient_gaps", {}).keys())
    if issues.get("protein_behind"):
        behind.append("protein")
    facts = {
        "behind_on": behind,
        "missed_logging": bool(issues.get("missed_logging")),
        "recipe": candidate["name"] if candidate else None,
        "recipe_makeable_now": bool(candidate and candidate.get("makeable")),
        "recipe_needs": [i["name"] for i in candidate["missing_ingredients"]] if candidate else [],
    }
    system = (
        "You are a nutrition coach. You are given computed facts. Never write a "
        "digit or quantity. Only mention the recipe named in the facts; if it is "
        "null, do not suggest any recipe."
    )
    prompt = f"Facts: {facts}\nWrite one specific action in fewer than 30 words."
    try:
        text = (await nemotron.complete(system, prompt, max_tokens=120, reasoning=False)).strip()
    except Exception:
        return fallback
    return text if prose_is_number_free(text) else fallback


@router.get("/pacing-status/{user_id}")
async def pacing_status(user_id: str, firestore: FirestoreService = Depends(get_firestore_service)):
    return firestore.get_daily_pace_status(user_id) or {"issues": {}, "updated_at": None}


@router.post("/pacing/check")
async def debug_pacing_check(
    request: PacingCheckRequest,
    firestore: FirestoreService = Depends(get_firestore_service),
    fcm: FcmService = Depends(get_fcm_service),
    nemotron: NemotronService = Depends(get_nemotron_service),
):
    return await check_and_alert(request.user_id, request.hour if request.hour is not None else datetime.now().hour, firestore, fcm, nemotron)
