import json
from fastapi import APIRouter, Depends, HTTPException, Query
from app.models.requests  import CreateRecipeRequest, VerifyRecipesRequest
from app.models.responses import CreateRecipeResponse, VerifyRecipesResponse, RecipeFlag
from app.services.nemotron_service  import NemotronService
from app.services.firestore_service import FirestoreService
from app.services.food_db_service import FoodDbService
from app.services.recipe_ingestion_service import RecipeIngestionService
from app.dependencies import get_food_db_service, get_nemotron_service, get_firestore_service

router = APIRouter()


@router.post("/recipes", response_model=CreateRecipeResponse)
@router.post("/recipes/ingest", response_model=CreateRecipeResponse, include_in_schema=False)
async def create_recipe(
    req: CreateRecipeRequest,
    nemotron_svc: NemotronService = Depends(get_nemotron_service),
    firestore_svc: FirestoreService = Depends(get_firestore_service),
    food_db_svc: FoodDbService = Depends(get_food_db_service),
):
    """Parse, nutrition-match, and persist a natural-language recipe for a meal slot."""
    service = RecipeIngestionService(food_db=food_db_svc, firestore=firestore_svc)
    result = await service.ingest(
        user_id=req.user_id,
        recipe_text=req.recipe_text,
        meal_slot=req.meal_slot,
        servings=req.servings,
        nemotron=nemotron_svc,
    )
    if not result["stored"]:
        raise HTTPException(status_code=503, detail="Recipe database is unavailable")
    return result


@router.get("/recipes")
async def list_recipes(
    user_id: str = Query(..., min_length=1),
    meal_slot: str | None = Query(default=None),
    firestore_svc: FirestoreService = Depends(get_firestore_service),
):
    """List stored recipes, optionally scoped to breakfast/lunch/dinner/snack."""
    recipes = firestore_svc.get_recipes(user_id)
    if meal_slot:
        allowed = {"breakfast", "lunch", "dinner", "snack"}
        if meal_slot not in allowed:
            raise HTTPException(status_code=422, detail="meal_slot must be breakfast, lunch, dinner, or snack")
        recipes = [r for r in recipes if r.get("mealSlot", r.get("meal_slot")) == meal_slot]
    return {"count": len(recipes), "recipes": recipes}


@router.post("/verify-recipes", response_model=VerifyRecipesResponse)
async def verify_recipes(
    req: VerifyRecipesRequest,
    nemotron_svc: NemotronService = Depends(get_nemotron_service),
    firestore_svc: FirestoreService = Depends(get_firestore_service),
):
    recipes = firestore_svc.get_recipes(req.user_id)
    system = (
        "You are a nutrition data auditor. "
        "Verify macros using: calories = (proteinG×4) + (carbsG×4) + (fatG×9). "
        "Flag discrepancy > 20 kcal. Return ONLY a JSON array."
    )
    user_msg = (
        f"Recipes:\n{json.dumps(recipes, indent=2)}\n\n"
        'Return: [{"recipe_name":"...","verified":true,"discrepancy_kcal":0,"flag_reason":null}]'
    )

    try:
        raw = await nemotron_svc.complete(system, user_msg, max_tokens=4000)
        clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        flags = [RecipeFlag(**f) for f in json.loads(clean)]
    except Exception:
        flags = []

    return VerifyRecipesResponse(flags=flags)
