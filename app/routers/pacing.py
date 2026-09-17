"""Pacing status API and scheduled alert orchestration."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.dependencies import get_fcm_service, get_firestore_service, get_nemotron_service
from app.services.fcm_service import FcmService
from app.services.firestore_service import FirestoreService
from app.services.nemotron_service import NemotronService
from app.services.pacing_service import detect_gaps

router = APIRouter()


class PacingCheckRequest(BaseModel):
    user_id: str = Field(min_length=1)
    hour: int | None = Field(default=None, ge=0, le=23)


async def check_and_alert(user_id: str, hour: int, firestore: FirestoreService, fcm: FcmService, nemotron: NemotronService) -> dict:
    diary = firestore.get_diary_history(user_id, days=1)
    today = datetime.now().strftime("%Y-%m-%d")
    diary = [entry for entry in diary if entry.get("date") == today]
    recipes = firestore.get_recipes(user_id)
    profile = firestore.get_user_profile(user_id)
    issues = detect_gaps(diary, recipes, hour, float(profile.get("proteinTargetG") or 155.0))
    status = {"issues": issues, "checkpoint_hour": hour}
    if not issues:
        firestore.save_daily_pace_status(user_id, status)
        return status

    inventory_names = [str(item.get("name")) for item in firestore.get_inventory(user_id) if item.get("name")]
    # An AI call is made only after the deterministic gap calculation above.
    system = "You are a nutrition coach. You are given real computed gaps. Never invent a number."
    prompt = (
        f"Detected issues: {issues}\nAvailable inventory: {inventory_names}\n"
        "Write one specific action in fewer than 40 words, using only the inventory."
    )
    try:
        message = await nemotron.complete(system, prompt, max_tokens=100)
    except Exception:
        message = "Log your next meal so Kinetik can update your nutrient pace."
    status["message"] = message.strip()
    firestore.save_daily_pace_status(user_id, status)
    token = profile.get("fcmToken")
    if token:
        fcm.send_pacing_alert(token, status["message"])
    return status


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
