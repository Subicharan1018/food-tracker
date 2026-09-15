from pydantic import BaseModel

class DiaryEntryIn(BaseModel):
    mealSlot:  str
    foodName:  str
    calories:  float
    proteinG:  float
    carbsG:    float
    fatG:      float
    fiberG:    float = 0.0

class MealPlanRequest(BaseModel):
    user_id:        str
    fcm_token:      str | None = None
    today_diary:    list[DiaryEntryIn] = []
    today_water_ml: int = 0

class WorkoutProgressionRequest(BaseModel):
    user_id:   str
    fcm_token: str | None = None

class ParseFoodRequest(BaseModel):
    user_id: str
    input:   str

class DigestTriggerRequest(BaseModel):
    user_id:   str
    fcm_token: str
    week:      str   # ISO format, e.g. "2026-W37"

class VerifyRecipesRequest(BaseModel):
    user_id: str
