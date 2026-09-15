from app.tools.diary_tools    import get_remaining_macros
from app.tools.recipe_tools   import search_recipes, get_gap_filler_snacks, get_recipe_detail
from app.tools.progress_tools import get_weight_trend, get_workout_trend, get_adherence_flags

TOOL_SCHEMAS = [
    {
        "type": "function",
        "function": {
            "name": "get_remaining_macros",
            "description": "Returns today's remaining macros vs athlete's target macros.",
            "parameters": {
                "type": "object",
                "properties": {
                    "today_diary": {"type": "array", "description": "List of meal entries logged today"}
                },
                "required": ["today_diary"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_recipes",
            "description": "Search recipes by meal slot, max calories, and minimum protein.",
            "parameters": {
                "type": "object",
                "properties": {
                    "meal_slot":   {"type": "string", "enum": ["breakfast", "lunch", "dinner", "snack"]},
                    "max_cal":     {"type": "integer"},
                    "min_protein": {"type": "integer"},
                },
                "required": ["meal_slot"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_gap_filler_snacks",
            "description": "Returns top 3 snacks that best close remaining calorie and protein gap.",
            "parameters": {
                "type": "object",
                "properties": {
                    "remaining_cal":     {"type": "integer"},
                    "remaining_protein": {"type": "integer"},
                },
                "required": ["remaining_cal", "remaining_protein"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_recipe_detail",
            "description": "Returns detailed nutrition profile for an exact recipe name.",
            "parameters": {
                "type": "object",
                "properties": {
                    "recipe_name": {"type": "string", "description": "Exact name of the recipe"}
                },
                "required": ["recipe_name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_weight_trend",
            "description": "Returns rolling average weight trend and total delta.",
            "parameters": {
                "type": "object",
                "properties": {"weeks": {"type": "integer", "default": 4}},
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_workout_trend",
            "description": "Returns last 5 logged sessions for a named exercise.",
            "parameters": {
                "type": "object",
                "properties": {
                    "exercise_name": {"type": "string"}
                },
                "required": ["exercise_name"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_adherence_flags",
            "description": "Returns plateau detection flag and 3-week weight delta.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
]

def make_dispatcher(
    today_diary: list[dict],
    recipes: list[dict],
    weigh_ins: list[dict],
    workout_logs: list[dict],
    user_profile: dict | None = None,
):
    """
    Returns an async dispatcher pre-loaded with request context.
    Extracts custom user targets from user_profile if available.
    """
    user_targets = None
    if user_profile:
        user_targets = {
            "calories": user_profile.get("calorieTarget"),
            "proteinG": user_profile.get("proteinTarget"),
            "carbsG":   user_profile.get("carbTarget"),
            "fatG":     user_profile.get("fatTarget"),
            "fiberG":   user_profile.get("fiberTarget"),
        }

    async def dispatcher(name: str, args: dict):
        if name == "get_remaining_macros":
            return await get_remaining_macros(today_diary, targets=user_targets)
        if name == "search_recipes":
            return await search_recipes(recipes, **args)
        if name == "get_gap_filler_snacks":
            return await get_gap_filler_snacks(recipes, **args)
        if name == "get_recipe_detail":
            return await get_recipe_detail(recipes, **args)
        if name == "get_weight_trend":
            return await get_weight_trend(weigh_ins, **args)
        if name == "get_workout_trend":
            return await get_workout_trend(workout_logs, **args)
        if name == "get_adherence_flags":
            return await get_adherence_flags(weigh_ins)
        return {"error": f"Unknown tool: {name}"}

    return dispatcher
