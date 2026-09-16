from fastapi import Header, HTTPException, Depends
from app.config import settings
from app.services.firestore_service import firestore_service, FirestoreService
from app.services.nemotron_service import nemotron_service, NemotronService
from app.services.context_builder import ContextBuilder
from app.services.fcm_service import fcm_service, FcmService
from app.services.digest_service import digest_service, DigestService
from app.services.workout_service import workout_service, WorkoutService
from app.services.food_db_service import food_db_service, FoodDbService

def get_firestore_service() -> FirestoreService:
    return firestore_service

def get_food_db_service() -> FoodDbService:
    return food_db_service

def get_nemotron_service() -> NemotronService:
    return nemotron_service

def get_context_builder(
    firestore_svc: FirestoreService = Depends(get_firestore_service),
) -> ContextBuilder:
    """Instantiates ContextBuilder using injected FirestoreService for full test isolation."""
    return ContextBuilder(firestore_svc=firestore_svc)

def get_fcm_service() -> FcmService:
    return fcm_service

def get_digest_service() -> DigestService:
    return digest_service

def get_workout_service() -> WorkoutService:
    return workout_service

async def verify_api_key(x_api_key: str | None = Header(default=None)):
    """Enforces API key authentication on protected routes if SERVER_API_KEY is configured."""
    if settings.server_api_key:
        if not x_api_key or x_api_key != settings.server_api_key:
            raise HTTPException(status_code=401, detail="Invalid or missing X-API-Key header")
    return True
