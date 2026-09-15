import pytest
from app.tools.diary_tools import get_remaining_macros, DEFAULT_TARGETS
from app.tools.recipe_tools import search_recipes, get_gap_filler_snacks, get_recipe_detail
from app.tools.progress_tools import get_weight_trend, get_workout_trend, get_adherence_flags
from app.tools.tool_registry import make_dispatcher, TOOL_SCHEMAS

@pytest.mark.asyncio
async def test_remaining_macros_custom_targets():
    diary = [
        {"calories": 500, "proteinG": 40, "carbsG": 50, "fatG": 15, "fiberG": 10},
    ]
    targets = {"calories": 2000, "proteinG": 150, "carbsG": 200, "fatG": 60, "fiberG": 30}
    res = await get_remaining_macros(diary, targets=targets)
    assert res["consumed"]["calories"] == 500.0
    assert res["consumed"]["proteinG"] == 40.0
    assert res["remaining"]["calories"] == 1500.0
    assert res["remaining"]["proteinG"] == 110.0
    assert res["targets"]["calories"] == 2000.0

@pytest.mark.asyncio
async def test_remaining_macros_default_fallback():
    diary = [
        {"calories": 350, "proteinG": 25, "carbsG": 40, "fatG": 10, "fiberG": 5},
    ]
    res = await get_remaining_macros(diary, targets=None)
    assert res["consumed"]["calories"] == 350.0
    assert res["targets"]["calories"] == DEFAULT_TARGETS["calories"]
    assert res["remaining"]["calories"] == DEFAULT_TARGETS["calories"] - 350.0
    assert res["remaining"]["proteinG"] == DEFAULT_TARGETS["proteinG"] - 25.0

@pytest.mark.asyncio
async def test_recipe_tools():
    recipes = [
        {"name": "Oatmeal Bowl", "mealSlot": "breakfast", "calories": 300, "proteinG": 15},
        {"name": "Paneer Tikka", "mealSlot": "dinner", "calories": 400, "proteinG": 32},
        {"name": "Greek Yogurt Snack", "mealSlot": "snack", "calories": 180, "proteinG": 20},
        {"name": "Whey Protein Shake", "mealSlot": "snack", "calories": 150, "proteinG": 25},
    ]
    # Search recipes
    search = await search_recipes(recipes, "breakfast", max_cal=400, min_protein=10)
    assert len(search) == 1
    assert search[0]["name"] == "Oatmeal Bowl"

    # Gap filler snacks: closest to 160 cal and 24g protein
    snacks = await get_gap_filler_snacks(recipes, remaining_cal=160, remaining_protein=24)
    assert len(snacks) == 2
    assert snacks[0]["name"] == "Whey Protein Shake"

    # Recipe detail lookup
    detail = await get_recipe_detail(recipes, "oatmeal bowl")
    assert detail["name"] == "Oatmeal Bowl"
    assert detail["calories"] == 300

    # Unknown recipe
    empty = await get_recipe_detail(recipes, "Nonexistent")
    assert empty == {}

@pytest.mark.asyncio
async def test_progress_tools():
    weigh_ins = [
        {"date": "2026-09-01", "weightKg": 75.0},
        {"date": "2026-09-08", "weightKg": 75.1},
        {"date": "2026-09-15", "weightKg": 75.0},
    ]
    trend = await get_weight_trend(weigh_ins)
    assert len(trend["trend"]) == 3
    assert trend["delta"] == 0.03
    assert trend["latest_avg"] == 75.03

    empty_trend = await get_weight_trend([])
    assert empty_trend["trend"] == []
    assert empty_trend["delta"] == 0.0

    workout_logs = [
        {"date": "2026-09-01", "exerciseName": "Bench Press", "weightKg": 70, "reps": 8},
        {"date": "2026-09-05", "exerciseName": "Bench Press", "weightKg": 72.5, "reps": 6},
        {"date": "2026-09-03", "exerciseName": "Squat", "weightKg": 100, "reps": 5},
    ]
    bench_logs = await get_workout_trend(workout_logs, "Bench Press")
    assert len(bench_logs) == 2
    assert bench_logs[0]["date"] == "2026-09-05"

    flags = await get_adherence_flags(weigh_ins)
    assert flags["plateau_detected"] is True
    assert flags["weight_delta_3wk"] == 0.0

@pytest.mark.asyncio
async def test_dispatcher_wires_all_six_tools():
    # Schema check
    schema_names = [s["function"]["name"] for s in TOOL_SCHEMAS]
    assert "get_remaining_macros" in schema_names
    assert "search_recipes" in schema_names
    assert "get_gap_filler_snacks" in schema_names
    assert "get_recipe_detail" in schema_names
    assert "get_weight_trend" in schema_names
    assert "get_workout_trend" in schema_names
    assert "get_adherence_flags" in schema_names

    dispatcher = make_dispatcher(
        today_diary=[{"calories": 200, "proteinG": 20}],
        recipes=[{"name": "Curd", "mealSlot": "snack", "calories": 100, "proteinG": 10}],
        weigh_ins=[{"date": "2026-09-01", "weightKg": 80.0}],
        workout_logs=[{"date": "2026-09-01", "exerciseName": "Deadlift"}],
        user_profile={"calorieTarget": 2600, "proteinTarget": 170},
    )

    # Dispatch get_recipe_detail
    detail = await dispatcher("get_recipe_detail", {"recipe_name": "Curd"})
    assert detail["name"] == "Curd"

    # Dispatch get_remaining_macros
    macros = await dispatcher("get_remaining_macros", {})
    assert macros["targets"]["calories"] == 2600.0
    assert macros["consumed"]["calories"] == 200.0

    # Dispatch search_recipes
    found = await dispatcher("search_recipes", {"meal_slot": "snack"})
    assert len(found) == 1

    # Dispatch get_weight_trend
    w_trend = await dispatcher("get_weight_trend", {})
    assert len(w_trend["trend"]) == 1

    # Dispatch get_workout_trend
    wo_trend = await dispatcher("get_workout_trend", {"exercise_name": "Deadlift"})
    assert len(wo_trend) == 1

    # Dispatch get_adherence_flags
    flags = await dispatcher("get_adherence_flags", {})
    assert "plateau_detected" in flags

    # Unknown tool
    err = await dispatcher("unknown_tool", {})
    assert "error" in err
