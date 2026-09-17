from app.services.nutrient_calculator import compute_recipe_nutrients


def test_exact_per_serving_nutrient_totals_and_missing_data_are_disclosed():
    recipe = {
        "servings": 2,
        "ingredients": [
            {"name": "spinach", "amount": 200, "unit": "g"},
            {"name": "mystery powder", "amount": 10, "unit": "g"},
        ],
    }
    nutrient_db = {
        "spinach": {
            "per_100g": {"iron_mg": 2.95, "folate_mcg": 142},
            "source": "IFCT 2017",
            "verified_date": "2017-01-01",
        }
    }
    result = compute_recipe_nutrients(recipe, nutrient_db)
    # 200 g / two portions = 100 g spinach per serving.
    assert result["totals"] == {"iron_mg": 2.95, "folate_mcg": 142.0}
    assert result["missing_data"] == ["mystery powder"]
    assert "IFCT 2017" in result["source"]


def test_legacy_ingredient_strings_are_rejected_not_parsed():
    result = compute_recipe_nutrients({"ingredientsJson": '["2 eggs"]'}, {})
    assert "structured" in result["error"]
