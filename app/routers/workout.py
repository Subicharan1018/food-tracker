from fastapi import APIRouter, Depends
from app.models.requests  import WorkoutProgressionRequest
from app.models.responses import WorkoutProgressionResponse
from app.services.workout_service import WorkoutService
from app.dependencies import get_workout_service

router = APIRouter()

@router.post("/workout-progression", response_model=WorkoutProgressionResponse)
async def get_workout_progression(
    req: WorkoutProgressionRequest,
    workout_svc: WorkoutService = Depends(get_workout_service),
):
    return await workout_svc.generate_workout_progression(req.user_id)
