from pydantic import BaseModel

class MealPlanItem(BaseModel):
    recipe_name: str
    meal_slot:   str
    calories:    float
    protein:     float
    reasoning:   str = ""

class MealPlanResponse(BaseModel):
    plan:     list[MealPlanItem]
    raw_text: str

class ExerciseProgression(BaseModel):
    name:           str
    current:        str
    recommendation: str
    reasoning:      str = ""

class WorkoutProgressionResponse(BaseModel):
    exercises: list[ExerciseProgression]
    raw_text:  str

class ParsedFoodItem(BaseModel):
    food_name:   str
    portion_qty: float = 1.0
    portion_unit: str | None = None
    meal_slot:   str = "snack"

class ParseFoodResponse(BaseModel):
    items:    list[ParsedFoodItem]
    raw_text: str

class DigestResponse(BaseModel):
    week:    str
    content: str
    cached:  bool

class RecipeFlag(BaseModel):
    recipe_name:      str
    verified:         bool
    discrepancy_kcal: float = 0.0
    flag_reason:      str | None = None

class VerifyRecipesResponse(BaseModel):
    flags: list[RecipeFlag]
