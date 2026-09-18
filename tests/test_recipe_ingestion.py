import json

import pytest

from app.services.recipe_ingestion_service import RecipeIngestionService


class _FakeFoodDb:
    foods = {
        "paneer": {
            "code": "L003", "name": "Paneer", "serving_size": 100,
            "energy_kcal": 257.9, "protein_g": 18.86, "carbohydrates_g": 12.41,
            "fat_g": 14.78, "fiber_g": 0,
        },
        "spinach": {
            "code": "C033", "name": "Spinach", "serving_size": 100,
            "energy_kcal": 24.4, "protein_g": 2.14, "carbohydrates_g": 2.05,
            "fat_g": 0.64, "fiber_g": 2.38,
        },
        "onion": {
            "code": "G017", "name": "Onion, big", "serving_size": 100,
            "energy_kcal": 48, "protein_g": 1.5, "carbohydrates_g": 9.56,
            "fat_g": 0.24, "fiber_g": 2.45,
        },
    }

    def search_foods(self, query, limit=20):
        query = query.lower()
        return [food for key, food in self.foods.items() if key in query or query in key]

    def get_food_by_code(self, code):
        for food in self.foods.values():
            if food.get("code") == code:
                return food
        return None


class _FakeFirestore:
    def __init__(self):
        self.saved = None

    def save_recipe(self, user_id, recipe_id, recipe):
        self.saved = (user_id, recipe_id, recipe)
        return True


class _FallbackAi:
    async def complete(self, system, user, max_tokens):
        return "not json"


@pytest.mark.asyncio
async def test_recipe_ingestion_parses_quantities_and_stores_meal_slot():
    firestore = _FakeFirestore()
    service = RecipeIngestionService(_FakeFoodDb(), firestore)
    result = await service.ingest(
        user_id="user123",
        meal_slot="lunch",
        servings=1,
        nemotron=_FallbackAi(),
        recipe_text=(
            "Palak Paneer\n"
            "- Paneer — 150 g\n"
            "- Palak — 180 g\n"
            "- Onion — ½ medium\n"
            "- Salt — to taste"
        ),
    )

    assert result["stored"] is True
    assert result["name"] == "Palak Paneer"
    assert result["meal_slot"] == "lunch"
    assert result["calories"] > 0
    assert firestore.saved[0] == "user123"
    assert firestore.saved[2]["mealSlot"] == "lunch"
    ingredients = json.loads(firestore.saved[2]["ingredientDetailsJson"])
    assert ingredients[0]["food_code"] == "L003"
    assert ingredients[1]["matched_food"] == "Spinach"
    assert any("IFCT match" in warning for warning in result["warnings"])


@pytest.mark.asyncio
async def test_recipe_ingestion_uses_structured_ai_result():
    class _Ai:
        async def complete(self, system, user, max_tokens):
            return '{"name":"Paneer Bowl","ingredients":[{"name":"Paneer","amount":50,"unit":"g","grams":50}]}'

    firestore = _FakeFirestore()
    service = RecipeIngestionService(_FakeFoodDb(), firestore)
    result = await service.ingest(
        user_id="user123",
        meal_slot="breakfast",
        servings=2,
        nemotron=_Ai(),
        recipe_text="Paneer Bowl\n- Paneer — 50 g",
    )

    assert result["name"] == "Paneer Bowl"
    assert result["meal_slot"] == "breakfast"
    assert result["calories"] == pytest.approx(64.475, abs=0.01)


@pytest.mark.asyncio
async def test_recipe_ingestion_counts_raw_rice_chicken_and_zero_energy_fats():
    class _EstimatorFoodDb:
        foods = {
            "chicken": {
                "code": "N002", "name": "Chicken, poultry, thigh, skinless",
                "serving_size": 100, "energy_kcal": 199.8,
                "protein_g": 18.18, "carbohydrates_g": 0, "fat_g": 14.23, "fiber_g": 0,
            },
            "rice": {
                "code": "A015", "name": "Rice, raw, milled",
                "serving_size": 100, "energy_kcal": 356.4,
                "protein_g": 7.94, "carbohydrates_g": 78.24, "fat_g": 0.52, "fiber_g": 1,
            },
            "oil": {
                "code": "T012", "name": "Sunflower oil",
                "serving_size": 100, "energy_kcal": 0,
                "protein_g": 0, "carbohydrates_g": 0, "fat_g": 100, "fiber_g": 0,
            },
            "ghee": {
                "code": "T013", "name": "Ghee",
                "serving_size": 100, "energy_kcal": 0,
                "protein_g": 0, "carbohydrates_g": 0, "fat_g": 100, "fiber_g": 0,
            },
        }

        def search_foods(self, query, limit=20):
            query = query.lower()
            return [food for key, food in self.foods.items() if key in query or query in key]

        def get_food_by_code(self, code):
            return next((food for food in self.foods.values() if food["code"] == code), None)

    firestore = _FakeFirestore()
    service = RecipeIngestionService(_EstimatorFoodDb(), firestore)
    result = await service.ingest(
        user_id="user123",
        meal_slot="lunch",
        servings=1,
        nemotron=_FallbackAi(),
        recipe_text=(
            "Chicken Seeraga Samba Rice\n"
            "- Chicken (raw, some skin) — 500 g\n"
            "- Seeraga samba rice (raw) — 250 g\n"
            "- Oil — 25 ml\n"
            "- Ghee — 5 g\n"
            "- Curd — 100 g"
        ),
    )

    # The previous implementation returned roughly 165 kcal because several
    # valid ingredients were not matched and IFCT oil/ghee energy is zero.
    assert result["calories"] > 2000
    assert result["protein_g"] > 100
    assert result["calories"] == pytest.approx(
        result["protein_g"] * 4 + result["carbs_g"] * 4 + result["fat_g"] * 9,
        abs=25,
    )


@pytest.mark.asyncio
async def test_recipe_ingestion_requires_validated_extraction_tool():
    class _ToolAi:
        async def extract_with_tool(self, system, user, tool_name, tool_description, tool_schema, max_tokens):
            assert tool_name == "extract_recipe"
            assert tool_schema["additionalProperties"] is False
            return {
                "name": "Rice Bowl",
                "meal_slot": "lunch",
                "method": "Mix and serve.",
                "ingredients": [{
                    "name": "Paneer", "amount": 50, "unit": "g", "grams": 50,
                    "state": "raw", "confidence": 0.99,
                }],
            }

    firestore = _FakeFirestore()
    service = RecipeIngestionService(_FakeFoodDb(), firestore)
    result = await service.ingest(
        user_id="user123",
        meal_slot="lunch",
        servings=1,
        nemotron=_ToolAi(),
        recipe_text="anything",
    )

    assert result["name"] == "Rice Bowl"
    assert result["calories"] == pytest.approx(128.95, abs=0.01)


@pytest.mark.asyncio
async def test_canonical_kinetik_format_bypasses_ai_and_uses_detected_servings():
    class _FailIfCalled:
        async def extract_with_tool(self, *args, **kwargs):
            raise AssertionError("canonical Kinetik format should not call the model")

    firestore = _FakeFirestore()
    service = RecipeIngestionService(_FakeFoodDb(), firestore)
    result = await service.ingest(
        user_id="user123",
        meal_slot="lunch",
        servings=1,
        nemotron=_FailIfCalled(),
        recipe_text=(
            "RECIPE: Paneer Bowl\n"
            "SERVINGS: 2\n\n"
            "INGREDIENTS:\n"
            "- Paneer | 100 | g | raw\n"
            "- Onion | 100 | g | raw\n\n"
            "METHOD:\nMix and serve."
        ),
    )

    assert result["servings"] == 2
    assert result["total_calories"] == pytest.approx(305.9, abs=0.1)
    assert result["calories"] == pytest.approx(152.95, abs=0.1)
