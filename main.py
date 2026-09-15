from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from app.config import settings, logger
from app.routers import meal_plan, workout, food_parser, digest, recipes
from app.services.firestore_service import FirestoreService
from app.dependencies import (
    get_firestore_service,
    get_digest_service,
    get_workout_service,
    verify_api_key,
)
from app.services.digest_service import DigestService
from app.services.workout_service import WorkoutService

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings.validate_production_config()
    from app.services.scheduler import start_scheduler, shutdown_scheduler
    start_scheduler()
    yield
    shutdown_scheduler()

app = FastAPI(title="Kinetik AI Server", version="1.0.0", lifespan=lifespan)

# Protected AI Routers: require X-API-Key when SERVER_API_KEY is configured
api_dependencies = [Depends(verify_api_key)]

app.include_router(meal_plan.router,   prefix="/ai", tags=["AI"], dependencies=api_dependencies)
app.include_router(workout.router,     prefix="/ai", tags=["AI"], dependencies=api_dependencies)
app.include_router(food_parser.router, prefix="/ai", tags=["AI"], dependencies=api_dependencies)
app.include_router(digest.router,      prefix="/ai", tags=["AI"], dependencies=api_dependencies)
app.include_router(recipes.router,     prefix="/ai", tags=["AI"], dependencies=api_dependencies)

@app.get("/health")
async def health():
    """Unauthenticated health check for uptime monitors & load balancers."""
    return {"status": "ok", "model": settings.nemotron_model}

class FcmTokenUpdate(BaseModel):
    user_id: str
    fcm_token: str

@app.post("/user/fcm-token", dependencies=api_dependencies)
async def update_fcm_token(
    body: FcmTokenUpdate,
    firestore_svc: FirestoreService = Depends(get_firestore_service),
):
    firestore_svc.update_fcm_token(body.user_id, body.fcm_token)
    return {"status": "updated"}

# ── DEBUG HOOKS (DEV ONLY — REMOVE OR GUARD BEFORE PROD) ────────────

@app.post("/debug/trigger-digest", dependencies=api_dependencies)
async def debug_trigger_digest(digest_svc: DigestService = Depends(get_digest_service)):
    """Dev only — manually fire the Sunday digest job."""
    if settings.environment == "production":
        raise HTTPException(status_code=404, detail="Not found")
    await digest_svc.run_weekly_digests()
    return {"status": "digest jobs completed"}

@app.post("/debug/trigger-progression", dependencies=api_dependencies)
async def debug_trigger_progression(workout_svc: WorkoutService = Depends(get_workout_service)):
    """Dev only — manually fire the Friday progression job."""
    if settings.environment == "production":
        raise HTTPException(status_code=404, detail="Not found")
    await workout_svc.run_workout_progressions()
    return {"status": "progression jobs completed"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.server_host,
        port=settings.server_port,
        workers=1,
    )

