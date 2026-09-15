from fastapi import APIRouter, BackgroundTasks, Depends
from app.models.requests  import DigestTriggerRequest
from app.models.responses import DigestResponse
from app.services.digest_service import DigestService
from app.services.firestore_service import FirestoreService
from app.dependencies import get_digest_service, get_firestore_service

router = APIRouter()

@router.post("/weekly-digest/trigger")
async def trigger_digest(
    req: DigestTriggerRequest,
    background_tasks: BackgroundTasks,
    digest_svc: DigestService = Depends(get_digest_service),
):
    background_tasks.add_task(digest_svc.generate_and_save, req.user_id, req.week, req.fcm_token)
    return {"status": "queued", "week": req.week}

@router.get("/weekly-digest/{user_id}/{week}", response_model=DigestResponse)
async def get_digest(
    user_id: str,
    week: str,
    firestore_svc: FirestoreService = Depends(get_firestore_service),
):
    cached = firestore_svc.get_digest(user_id, week)
    if cached:
        return DigestResponse(week=week, content=cached.get("content", ""), cached=True)
    return DigestResponse(week=week, content="", cached=False)
