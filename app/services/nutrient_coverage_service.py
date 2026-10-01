"""Weekly inventory ceiling calculations for micronutrients, with structural-gap
detail that feeds the Shopping List and Shopping Cart features.

All outputs carry a `computed_at` timestamp.  The AI layer never touches numbers
produced here — it only writes prose over this deterministic output.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from app.data.rda_targets import DAILY_RDA, WEEKLY_RDA
from app.services.ingredient_identity import canonicalize
from app.services.nutrient_calculator import (
    TRACKED_NUTRIENTS,
    compute_recipe_nutrients,
    resolve_profile,
    to_grams,
)

REALISTIC_WEEKLY_CAP_G = 1000.0  # transparent modelling cap, not a consumption prediction

# A recipe "fixes" a gap only if one serving is a meaningful source, not a trace.
MEANINGFUL_SERVING_FRACTION = 0.20

# Ingredients assumed to be on tap; never worth a cart row.
_NEVER_SHOP = {"water"}


def compute_weekly_nutrient_ceiling(
    inventory: list[dict[str, Any]],
    nutrient_db: dict[str, dict],
    food_db=None,
) -> dict[str, Any]:
    """Compute achievable weekly micronutrient ceiling from current inventory.

    Returns:
        label:            Always "Up to this amount, if you cook optimally" — a
                          ceiling, never a consumption prediction.
        coverage:         Per-nutrient achievable amount vs weekly RDA target.
        structural_gaps:  List of nutrient keys below 50 % of weekly RDA.
        missing_data:     Inventory items with no cited profile or no known weight.
        sources:          Every source citation that contributed a number.
        computed_at:      ISO-8601 UTC timestamp.
    """
    totals = {nutrient: 0.0 for nutrient in TRACKED_NUTRIENTS}
    supported = {nutrient: False for nutrient in TRACKED_NUTRIENTS}
    missing: list[str] = []
    sources: set[str] = set()
    for item in inventory:
        raw_name = str(item.get("canonicalName") or item.get("name") or "").strip()
        name = canonicalize(raw_name)
        if not name:
            continue
        profile = resolve_profile(name, nutrient_db, food_db)
        if not profile or profile.get("source") == "UNAVAILABLE":
            missing.append(name)
            continue
        unit = item.get("unit") or "g"
        grams = to_grams(item.get("quantity") if item.get("quantity") is not None else item.get("grams"), unit, name)
        if grams is None:
            missing.append(f"{name} (unknown weight for '{unit}')")
            continue
        grams = min(max(grams, 0.0), REALISTIC_WEEKLY_CAP_G)
        sources.add(_citation(profile))
        for nutrient, value in profile.get("per_100g", {}).items():
            if nutrient in totals:
                totals[nutrient] += float(value) * grams / 100.0
                supported[nutrient] = True
    coverage = {}
    gaps = []
    unmeasured = []
    for nutrient in TRACKED_NUTRIENTS:
        target = WEEKLY_RDA.get(nutrient)
        if target is None:
            continue
        if not supported[nutrient]:
            # No cited source covers it — reported separately, never as 0 %.
            unmeasured.append(nutrient)
            continue
        pct = round(totals[nutrient] / target * 100, 1)
        coverage[nutrient] = {"achievable": round(totals[nutrient], 2), "target": target, "pct": pct}
        if pct < 50:
            gaps.append(nutrient)
    return {
        "label": "Up to this amount, if you cook optimally",
        "coverage": coverage,
        "structural_gaps": gaps,
        "unmeasured_nutrients": unmeasured,
        "missing_data": sorted(set(missing)),
        "sources": sorted(sources),
        "computed_at": datetime.now(timezone.utc).isoformat(),
        "weekly_cap_g": REALISTIC_WEEKLY_CAP_G,
    }


def _in_stock(item: dict[str, Any]) -> bool:
    quantity = item.get("quantity")
    try:
        return quantity is None or float(quantity) > 0
    except (TypeError, ValueError):
        return True


def inventory_canonical_names(inventory: list[dict[str, Any]]) -> set[str]:
    """Canonical names of what's actually in stock (used-up rows don't count)."""
    return {
        canonicalize(str(item.get("canonicalName") or item.get("name") or ""))
        for item in inventory
        if (item.get("canonicalName") or item.get("name")) and _in_stock(item)
    } - {""}


def missing_ingredients_for(recipe: dict[str, Any], pantry: set[str]) -> list[dict[str, Any]]:
    """Ingredients of ``recipe`` that are not in the pantry, with the recipe's own amounts."""
    missing: list[dict[str, Any]] = []
    seen: set[str] = set()
    for ing in _parse_ingredients(recipe):
        raw_name = str(ing.get("ingredient") or ing.get("name") or "").strip()
        canon = canonicalize(raw_name)
        if not canon or canon in pantry or canon in seen or canon in _NEVER_SHOP:
            continue
        seen.add(canon)
        entry: dict[str, Any] = {"name": raw_name, "canonical_name": canon}
        amount = ing.get("grams") if ing.get("grams") is not None else ing.get("amount")
        unit = "g" if ing.get("grams") is not None else ing.get("unit")
        try:
            if amount is not None and float(amount) > 0:
                entry["quantity"] = round(float(amount), 2)
                entry["unit"] = str(unit or "pieces")
        except (TypeError, ValueError):
            pass
        missing.append(entry)
    return missing


class RecipeNutrientCache:
    """Computes each recipe's per-serving nutrients once per job run."""

    def __init__(self, nutrient_db: dict[str, dict], food_db=None):
        self._nutrient_db = nutrient_db
        self._food_db = food_db
        self._cache: dict[int, dict[str, Any]] = {}

    def per_serving(self, recipe: dict[str, Any]) -> dict[str, Any]:
        key = id(recipe)
        if key not in self._cache:
            self._cache[key] = compute_recipe_nutrients(recipe, self._nutrient_db, self._food_db)
        return self._cache[key]


def rank_recipes_for_nutrient(
    nutrient: str,
    recipes: list[dict[str, Any]],
    pantry: set[str],
    cache: RecipeNutrientCache,
    min_fraction: float = MEANINGFUL_SERVING_FRACTION,
) -> list[dict[str, Any]]:
    """Recipes that are a meaningful source of ``nutrient``, best per-serving amount first."""
    daily_target = DAILY_RDA.get(nutrient)
    if daily_target is None:
        return []
    ranked = []
    for recipe in recipes:
        result = cache.per_serving(recipe)
        amount = result.get("totals", {}).get(nutrient, 0.0)
        if amount < daily_target * min_fraction:
            continue
        ranked.append({
            "name": recipe.get("name", ""),
            "recipe_id": recipe.get("id", ""),
            "nutrient": nutrient,
            "per_serving_amount": round(amount, 2),
            "sources": result.get("source", []),
            "missing_ingredients": missing_ingredients_for(recipe, pantry),
        })
    ranked.sort(key=lambda r: r["per_serving_amount"], reverse=True)
    return ranked


def compute_structural_gaps_detail(
    structural_gaps: list[str],
    recipes: list[dict[str, Any]],
    inventory: list[dict[str, Any]],
    nutrient_db: dict[str, dict],
    food_db=None,
    cache: RecipeNutrientCache | None = None,
) -> list[dict[str, Any]]:
    """For each structural gap nutrient, identify which recipe would be unlocked
    and which specific ingredients are missing from inventory to make it.

    Every item in `missing_ingredients` maps directly to an "Add to Cart"
    action on the frontend.  If all ingredients are already in inventory the
    recipe is still listed (the gap is structural because it isn't being
    cooked, not because it can't be).
    """
    cache = cache or RecipeNutrientCache(nutrient_db, food_db)
    pantry = inventory_canonical_names(inventory)
    results: list[dict[str, Any]] = []
    for nutrient in structural_gaps:
        ranked = rank_recipes_for_nutrient(nutrient, recipes, pantry, cache)
        if not ranked:
            continue
        best = ranked[0]
        results.append({
            "nutrient": nutrient,
            "unlocks_recipe": best["name"],
            "recipe_id": best["recipe_id"],
            "per_serving_amount": best["per_serving_amount"],
            "sources": best["sources"],
            "missing_ingredients": best["missing_ingredients"],
        })
    return results


def find_candidate_recipe(
    nutrients: list[str],
    recipes: list[dict[str, Any]],
    inventory: list[dict[str, Any]],
    nutrient_db: dict[str, dict],
    food_db=None,
    max_missing: int = 3,
) -> dict[str, Any] | None:
    """Pick the single recipe the pacing alert is allowed to talk about.

    Nutrients are tried in the given priority order.  A recipe makeable from
    the current pantry always wins; otherwise the closest recipe (fewest
    missing ingredients, at most ``max_missing``) is returned with its
    shopping delta.  The AI never chooses or invents the recipe.
    """
    cache = RecipeNutrientCache(nutrient_db, food_db)
    pantry = inventory_canonical_names(inventory)
    for nutrient in nutrients:
        # Intraday: a tenth of the day's target in one serving is a real dent.
        ranked = rank_recipes_for_nutrient(nutrient, recipes, pantry, cache, min_fraction=0.10)
        makeable = [r for r in ranked if not r["missing_ingredients"]]
        if makeable:
            return {**makeable[0], "makeable": True}
        close = sorted(
            (r for r in ranked if len(r["missing_ingredients"]) <= max_missing),
            key=lambda r: (len(r["missing_ingredients"]), -r["per_serving_amount"]),
        )
        if close:
            return {**close[0], "makeable": False}
    return None


def aggregate_shopping_items(gaps_detail: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Flatten gap details into one de-duplicated buy list, keyed by canonical name."""
    items: dict[str, dict[str, Any]] = {}
    for gap in gaps_detail:
        for ing in gap.get("missing_ingredients", []):
            canon = ing["canonical_name"]
            item = items.get(canon)
            if item is None:
                item = items[canon] = {
                    "name": ing["name"],
                    "canonical_name": canon,
                    "unlocks": [],
                    "nutrients": [],
                }
                if "quantity" in ing:
                    item["quantity"] = ing["quantity"]
                    item["unit"] = ing["unit"]
            if gap["unlocks_recipe"] and gap["unlocks_recipe"] not in item["unlocks"]:
                item["unlocks"].append(gap["unlocks_recipe"])
            if gap["nutrient"] not in item["nutrients"]:
                item["nutrients"].append(gap["nutrient"])
    # Ingredients that unlock the most gaps first.
    return sorted(items.values(), key=lambda i: (-len(i["nutrients"]), i["canonical_name"]))


def _citation(profile: dict[str, Any]) -> str:
    source = str(profile.get("source") or "Unknown source")
    code = profile.get("ifct_code")
    return f"{source} · {code}" if code and "#" not in source else source


def _parse_ingredients(recipe: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract structured ingredient list from a recipe dict (handles both field names)."""
    raw = recipe.get("ingredientDetailsJson") or recipe.get("ingredientsJson") or recipe.get("ingredients")
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            return []
    if isinstance(raw, list):
        return [item for item in raw if isinstance(item, dict)]
    return []
