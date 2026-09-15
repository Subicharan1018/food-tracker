import json
from fastapi import APIRouter, Depends
from app.models.requests  import ParseFoodRequest
from app.models.responses import ParseFoodResponse, ParsedFoodItem
from app.services.nemotron_service  import NemotronService
from app.services.firestore_service import FirestoreService
from app.dependencies import get_nemotron_service, get_firestore_service

router = APIRouter()

@router.post("/parse-food", response_model=ParseFoodResponse)
async def parse_food(
    req: ParseFoodRequest,
    nemotron_svc: NemotronService = Depends(get_nemotron_service),
    firestore_svc: FirestoreService = Depends(get_firestore_service),
):
    recipes = firestore_svc.get_recipes(req.user_id)
    names = [r.get("name", "") for r in recipes]

    system = (
        "You are a food log parser. Map free-text food entries to exact names from the "
        "provided database. Return ONLY a JSON array. No preamble. No markdown."
    )
    user_msg = (
        f'Database names: {json.dumps(names)}\n\n'
        f'Entry: "{req.input}"\n\n'
        'Return: [{"food_name":"...","portion_qty":1.0,"meal_slot":"breakfast"}]'
    )

    try:
        raw = await nemotron_svc.complete(system, user_msg, max_tokens=500)
        clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        items = [ParsedFoodItem(**i) for i in json.loads(clean)]
    except Exception:
        items = []
        raw = ""

    return ParseFoodResponse(items=items, raw_text=raw)
