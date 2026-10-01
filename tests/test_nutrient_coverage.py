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
    firestore.get_diary_history.return_value = [{"date": today, "foodName": "toast", "proteinG": 10}]
    firestore.get_recipes.return_value = [_recipe("Keerai Kootu", {"name": "spinach", "amount": 150, "unit": "g"})]
    firestore.get_user_profile.return_value = {}
    firestore.get_inventory.return_value = [{"name": "spinach", "quantity": 500, "unit": "g"}]
    nemotron = MagicMock()
    nemotron.complete = AsyncMock(return_value="Eat 300 g of spinach now.")

    status = await check_and_alert("u1", 17, firestore, MagicMock(), nemotron, food_db=None)

    assert status["candidate_recipe"]["name"] == "Keerai Kootu"
    assert status["candidate_recipe"]["makeable"] is True
    assert "300" not in status["message"]
    assert "Keerai Kootu" in status["message"]
