import json
from fastapi import APIRouter, Depends
from app.models.requests  import VerifyRecipesRequest
from app.models.responses import VerifyRecipesResponse, RecipeFlag
from app.services.nemotron_service  import NemotronService
from app.services.firestore_service import FirestoreService
from app.dependencies import get_nemotron_service, get_firestore_service

router = APIRouter()

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
