import json
from fastapi import APIRouter, Depends
from app.models.requests  import MealPlanRequest
from app.models.responses import MealPlanResponse, MealPlanItem
from app.services.nemotron_service import NemotronService
from app.services.context_builder  import ContextBuilder
from app.services.firestore_service import FirestoreService
from app.dependencies import get_nemotron_service, get_context_builder, get_firestore_service
from app.tools.tool_registry import TOOL_SCHEMAS, make_dispatcher

router = APIRouter()

@router.post("/meal-plan", response_model=MealPlanResponse)
async def get_meal_plan(
    req: MealPlanRequest,
    nemotron_svc: NemotronService = Depends(get_nemotron_service),
    context_bld: ContextBuilder = Depends(get_context_builder),
    firestore_svc: FirestoreService = Depends(get_firestore_service),
):
    system = context_bld.build(req.user_id, include_workouts=False, include_weigh_ins=False)
    profile = firestore_svc.get_user_profile(req.user_id)
    recipes = firestore_svc.get_recipes(req.user_id)
    weigh_ins = firestore_svc.get_weigh_ins(req.user_id)
    workout_logs = []

    today_diary_raw = [e.model_dump() for e in req.today_diary]
    dispatcher = make_dispatcher(today_diary_raw, recipes, weigh_ins, workout_logs, profile)

    user_msg = (
        f"Today's meals so far: {json.dumps(today_diary_raw)}\n"
        f"Today's water logged: {req.today_water_ml} ml\n\n"
        "Use the tools to check remaining macros, find a dinner recipe, "
        "and find snacks to close the calorie and protein gap. "
        "Return ONLY a JSON array: "
        '[{"recipe_name":"...","meal_slot":"...","calories":0,"protein":0,"reasoning":"..."}]'
    )

    try:
        raw = await nemotron_svc.run_agent_loop(system, user_msg, TOOL_SCHEMAS, dispatcher)
        clean = raw.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        plan_data = json.loads(clean)
        plan = [MealPlanItem(**item) for item in plan_data]
    except Exception:
        plan = []
        raw = ""

    return MealPlanResponse(plan=plan, raw_text=raw)
