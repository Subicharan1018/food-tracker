from unittest.mock import AsyncMock, MagicMock

import pytest

from app.routers.pacing import check_and_alert
from app.services.nutrient_calculator import resolve_profile
from app.services.nutrient_coverage_service import (
    aggregate_shopping_items,
    compute_structural_gaps_detail,
    compute_weekly_nutrient_ceiling,
    find_candidate_recipe,
)
from app.services.shopping_list_service import build_weekly_shopping_list, prose_is_number_free

SPINACH = {"per_100g": {"iron_mg": 2.7, "folate_mcg": 142.0}, "source": "IFCT 2017", "ifct_code": "D032"}
RAJMA = {"per_100g": {"iron_mg": 8.0}, "source": "USDA FDC #173744"}
NUTRIENT_DB = {"spinach": SPINACH, "kidney beans": RAJMA}


class FakeFoodDb:
    def __init__(self, rows):
        self.rows = rows

    def search_foods(self, query, limit=20):
        return self.rows

    def get_food_by_code(self, code):
        return next((r for r in self.rows if r.get("code") == code), None)


def _recipe(name, *ingredients, rid=None):
    return {"id": rid or name.lower().replace(" ", "_"), "name": name, "servings": 1, "ingredients": list(ingredients)}


# ── Resolver: never attach a fuzzy IFCT hit ─────────────────────────────────

def test_resolver_rejects_fuzzy_ifct_hits():
    # The real FTS index returns brinjal rows for "egg" and bulgur for "oats".
    food_db = FakeFoodDb([{"code": "D001", "name": "Brinjal 1", "iron_mg": 0.4}])
    assert resolve_profile("egg", {}, food_db) is None


def test_resolver_rejects_ambiguous_variants():
    food_db = FakeFoodDb([
        {"code": "D1", "name": "Onion, big", "iron_mg": 0.5},
        {"code": "D2", "name": "Onion, small", "iron_mg": 0.6},
    ])
    assert resolve_profile("onion", {}, food_db) is None


def test_resolver_accepts_single_exact_ifct_match_with_citation():
    food_db = FakeFoodDb([
        {"code": "D5", "name": "Agathi leaves", "iron_mg": 3.9},
        {"code": "D32", "name": "Spinach", "iron_mg": 2.7},
    ])
    profile = resolve_profile("Keerai", {}, food_db)  # Tamil synonym → spinach
    assert profile["ifct_code"] == "D32"
    assert profile["per_100g"]["iron_mg"] == 2.7


# ── Weekly ceiling ──────────────────────────────────────────────────────────

def test_ceiling_converts_units_and_reports_unknown_weights():
    inventory = [
        {"name": "Keerai", "quantity": 0.5, "unit": "kg"},
        {"name": "spinach", "quantity": 2, "unit": "bunch"},
    ]
    result = compute_weekly_nutrient_ceiling(inventory, NUTRIENT_DB)
    assert result["coverage"]["iron_mg"]["achievable"] == pytest.approx(13.5)
    assert "spinach (unknown weight for 'bunch')" in result["missing_data"]
    assert result["label"].startswith("Up to")
    assert result["computed_at"]
    # Nutrients no cited source covers are listed, never shown as 0 %.
    assert "b12_mcg" in result["unmeasured_nutrients"]
    assert "b12_mcg" not in result["coverage"]


# ── Gaps → cart items ───────────────────────────────────────────────────────

def test_gap_detail_uses_canonical_names_and_recipe_amounts():
    recipes = [_recipe("Palak Rajma", {"name": "Palak", "amount": 200, "unit": "g"},
                       {"name": "Rajma", "amount": 100, "unit": "g"}, {"name": "water", "amount": 1, "unit": "cup"})]
    inventory = [{"name": "spinach", "quantity": 100, "unit": "g"}]
    detail = compute_structural_gaps_detail(["iron_mg"], recipes, inventory, NUTRIENT_DB)
    assert detail[0]["unlocks_recipe"] == "Palak Rajma"
    # palak is owned (as spinach); water is never a cart item.
    assert detail[0]["missing_ingredients"] == [
        {"name": "Rajma", "canonical_name": "kidney beans", "quantity": 100.0, "unit": "g"}
    ]


def test_aggregate_dedupes_one_ingredient_across_gaps():
    gaps = [
        {"nutrient": "iron_mg", "unlocks_recipe": "A", "missing_ingredients": [{"name": "Rajma", "canonical_name": "kidney beans"}]},
        {"nutrient": "folate_mcg", "unlocks_recipe": "B", "missing_ingredients": [{"name": "rajma", "canonical_name": "kidney beans"}]},
    ]
    items = aggregate_shopping_items(gaps)
    assert len(items) == 1
    assert items[0]["unlocks"] == ["A", "B"]
    assert items[0]["nutrients"] == ["iron_mg", "folate_mcg"]


def test_candidate_prefers_makeable_recipe_over_richer_one():
    rich = _recipe("Rajma Masala", {"name": "rajma", "amount": 300, "unit": "g"})
    owned = _recipe("Keerai Kootu", {"name": "spinach", "amount": 150, "unit": "g"})
    inventory = [{"name": "spinach", "quantity": 500, "unit": "g"}]
    candidate = find_candidate_recipe(["iron_mg"], [rich, owned], inventory, NUTRIENT_DB)
    assert candidate["name"] == "Keerai Kootu"
    assert candidate["makeable"] is True


def test_candidate_returns_shopping_delta_when_nothing_is_makeable():
    rich = _recipe("Rajma Masala", {"name": "rajma", "amount": 300, "unit": "g"})
    candidate = find_candidate_recipe(["iron_mg"], [rich], [], NUTRIENT_DB)
    assert candidate["makeable"] is False
    assert [i["canonical_name"] for i in candidate["missing_ingredients"]] == ["kidney beans"]


# ── AI guardrails ───────────────────────────────────────────────────────────

def test_prose_guard_rejects_any_digit():
    assert prose_is_number_free("Pick up rajma to unlock Rajma Masala.")
    assert not prose_is_number_free("Rajma gives 8 mg iron.")
    assert not prose_is_number_free("   ")


@pytest.mark.asyncio
async def test_shopping_list_makes_no_ai_call_without_gaps(monkeypatch):
    monkeypatch.setattr("app.services.shopping_list_service.load_nutrient_profiles", lambda: NUTRIENT_DB)
    firestore = MagicMock()
    firestore.get_inventory.return_value = []
    firestore.get_recipes.return_value = []
    nemotron = MagicMock()
    nemotron.complete = AsyncMock(return_value="unused")
    payload = await build_weekly_shopping_list("u1", firestore, None, nemotron)
    nemotron.complete.assert_not_called()
    assert payload["shopping_list"] == []
    firestore.save_shopping_list.assert_called_once()


@pytest.mark.asyncio
async def test_pacing_alert_discards_ai_numbers_and_names_precomputed_recipe(monkeypatch):
    from datetime import datetime

    monkeypatch.setattr("app.routers.pacing.load_nutrient_profiles", lambda: NUTRIENT_DB)
    today = datetime.now().strftime("%Y-%m-%d")
    firestore = MagicMock()
    firestore.get_diary_history.return_value = [{"date": today, "foodName": "Toast", "proteinG": 10, "portionQty": 1}]
    firestore.get_recipes.return_value = [
        {**_recipe("Toast", {"name": "bread", "amount": 60, "unit": "g"}), "nutrients": {"iron_mg": 0.5}},
        _recipe("Keerai Kootu", {"name": "spinach", "amount": 150, "unit": "g"}),
    ]
    firestore.get_user_profile.return_value = {}
    firestore.get_inventory.return_value = [{"name": "spinach", "quantity": 500, "unit": "g"}]
    nemotron = MagicMock()
    nemotron.complete = AsyncMock(return_value="Eat 300 g of spinach now.")

    status = await check_and_alert("u1", 17, firestore, MagicMock(), nemotron, food_db=None)

    assert status["candidate_recipe"]["name"] == "Keerai Kootu"
    assert status["candidate_recipe"]["makeable"] is True
    assert "300" not in status["message"]
    assert "Keerai Kootu" in status["message"]


# ── Diary micronutrients: every cited food counts, nothing is zero-filled ──

from app.services.pacing_service import detect_gaps, diary_micronutrients, entry_grams


class _IfctDb:
    def get_food_by_code(self, code):
        return {"code": code, "name": "Spinach", "iron_mg": 2.7, "calcium_mg": 99.0} if code == "D032" else None


def test_foods_logged_from_ifct_search_count_by_weight():
    diary = [{"foodName": "Spinach (Palak)", "foodItemId": "ifct_d032", "portionQty": 200, "portionUnit": "g"}]
    result = diary_micronutrients(diary, [], _IfctDb())
    assert result["totals"]["iron_mg"] == pytest.approx(5.4)
    assert result["counted"] == ["Spinach (Palak)"]
    assert result["measured"] == {"iron_mg", "calcium_mg"}


def test_unweighable_and_unknown_foods_are_listed_not_zeroed():
    diary = [
        {"foodName": "Spinach", "foodItemId": "ifct_d032", "portionQty": 1, "portionUnit": "serving"},
        {"foodName": "Homemade sambar", "portionQty": 1, "portionUnit": "bowl"},
    ]
    result = diary_micronutrients(diary, [], _IfctDb())
    assert result["uncounted"] == ["Spinach", "Homemade sambar"]
    assert result["measured"] == set()


def test_unmeasured_nutrients_are_never_flagged_behind():
    diary = [{"foodName": "Spinach", "foodItemId": "ifct_d032", "portionQty": 100, "portionUnit": "g", "proteinG": 200}]
    issues = detect_gaps(diary, [], 21, food_db=_IfctDb())
    # Iron and calcium were measured (and are low); B12 had no source, so it isn't claimed.
    assert set(issues["nutrient_gaps"]) == {"iron_mg", "calcium_mg"}


def test_recipe_match_uses_canonical_names():
    recipes = [{"name": "Keerai Kootu", "nutrients": {"iron_mg": 4.0}}]
    diary = [{"foodName": "  keerai kootu ", "portionQty": 2}]
    assert diary_micronutrients(diary, recipes)["totals"]["iron_mg"] == 8.0


def test_entry_grams_reads_weight_from_count_units():
    assert entry_grams({"portionQty": 2, "portionUnit": "egg (~55g)"}) == 110
    assert entry_grams({"portionQty": 0.5, "portionUnit": "kg"}) == 500
    assert entry_grams({"portionQty": 1, "portionUnit": "cup"}) is None


def test_used_up_pantry_rows_do_not_count_as_owned():
    recipes = [_recipe("Keerai Kootu", {"name": "spinach", "amount": 150, "unit": "g"})]
    used_up = [{"name": "spinach", "quantity": 0, "unit": "g"}]
    candidate = find_candidate_recipe(["iron_mg"], recipes, used_up, NUTRIENT_DB)
    assert candidate["makeable"] is False
