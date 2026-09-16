import json
from fastapi import APIRouter, Depends
from app.models.requests  import ParseFoodRequest
from app.models.responses import ParseFoodResponse, ParsedFoodItem
from app.services.nemotron_service  import NemotronService
from app.services.firestore_service import FirestoreService
from app.services.food_db_service import FoodDbService
from app.dependencies import get_nemotron_service, get_firestore_service, get_food_db_service

router = APIRouter()

@router.post("/parse-food", response_model=ParseFoodResponse)
async def parse_food(
    req: ParseFoodRequest,
    nemotron_svc: NemotronService = Depends(get_nemotron_service),
    firestore_svc: FirestoreService = Depends(get_firestore_service),
    food_db_svc: FoodDbService = Depends(get_food_db_service),
):
    recipes = firestore_svc.get_recipes(req.user_id)
    recipe_names = [r.get("name", "") for r in recipes if r.get("name")]
    
    # Query relevant candidate food items from IFCT 2017 database
    ifct_candidates = food_db_svc.search_foods(req.input, limit=15)
    ifct_names = [f["name"] for f in ifct_candidates]

    combined_names = list(dict.fromkeys(recipe_names + ifct_names))

    system = (
        "You are a food log parser. Map free-text food entries to exact names from the "
        "provided database. Return ONLY a JSON array. No preamble. No markdown."
    )
    user_msg = (
        f'Database names: {json.dumps(combined_names)}\n\n'
        f'Entry: "{req.input}"\n\n'
        'Return: [{"food_name":"...","portion_qty":200,"portion_unit":"g","meal_slot":"breakfast"}]. '
        'Use the database serving unit when no unit is written. Preserve explicit units such as g, kg, ml, '
        'piece, egg, scoop, cup, tbsp, or serving.'
    )

    try:
        raw = await nemotron_svc.complete(system, user_msg, max_tokens=500)
        clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        items = [ParsedFoodItem(**i) for i in json.loads(clean)]
    except Exception:
        items = []
        raw = ""

    return ParseFoodResponse(items=items, raw_text=raw)
