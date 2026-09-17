from pydantic import BaseModel, Field

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


class RecipeIngredientResult(BaseModel):
    ingredient: str
    matched_food: str | None = None
    food_code: str | None = None
    amount: float | None = None
    unit: str | None = None
    grams: float = 0.0
    calories: float = 0.0
    protein_g: float = 0.0
    carbs_g: float = 0.0
    fat_g: float = 0.0
    fiber_g: float = 0.0
    resolved: bool = False


class CreateRecipeResponse(BaseModel):
    id: str
    name: str
    meal_slot: str
    servings: float
    calories: float
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float
    method: str = ""
    ingredients: list[RecipeIngredientResult]
    warnings: list[str] = Field(default_factory=list)
    nutrients: dict[str, float] = Field(default_factory=dict)
    nutrient_meta: dict = Field(default_factory=dict)
    stored: bool
