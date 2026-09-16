from typing import Literal
from pydantic import AliasChoices, BaseModel, Field

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


class CreateRecipeRequest(BaseModel):
    """Natural-language recipe submitted to the AI recipe ingestion agent."""

    user_id: str = Field(min_length=1)
    recipe_text: str = Field(
        min_length=3,
        validation_alias=AliasChoices("recipe_text", "input"),
        description="Markdown, plain text, or a natural-language recipe description",
    )
    meal_slot: Literal["breakfast", "lunch", "dinner", "snack"] = Field(
        default="lunch",
        validation_alias=AliasChoices("meal_slot", "mealSlot"),
    )
    servings: float = Field(default=1.0, gt=0, le=100)
