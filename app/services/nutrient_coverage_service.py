"""Weekly inventory ceiling calculations for micronutrients, with structural-gap
detail that feeds the Shopping List and Shopping Cart features.

All outputs carry a `computed_at` timestamp.  The AI layer never touches numbers
produced here — it only writes prose over this deterministic output.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.data.rda_targets import WEEKLY_RDA
from app.services.nutrient_calculator import (
    TRACKED_NUTRIENTS,
    _normalise,
    compute_recipe_nutrients,
)

REALISTIC_WEEKLY_CAP_G = 1000.0  # transparent modelling cap, not a consumption prediction


def compute_weekly_nutrient_ceiling(
    inventory: list[dict[str, Any]],
    nutrient_db: dict[str, dict],
) -> dict[str, Any]:
    """Compute achievable weekly micronutrient ceiling from current inventory.

    Returns:
        label:            Always "Up to this amount, if you cook optimally" — a
                          ceiling, never a consumption prediction.
        coverage:         Per-nutrient achievable amount vs weekly RDA target.
        structural_gaps:  List of nutrient keys below 50 % of weekly RDA.
        missing_data:     Inventory items with no nutrient profile in either source.
        computed_at:      ISO-8601 UTC timestamp.
    """
    totals = {nutrient: 0.0 for nutrient in TRACKED_NUTRIENTS}
    supported = {nutrient: False for nutrient in TRACKED_NUTRIENTS}
    missing: list[str] = []
    for item in inventory:
        name = str(item.get("name") or "").strip().lower()
        profile = nutrient_db.get(name)
        if not profile or profile.get("source") == "UNAVAILABLE":
            if name:
                missing.append(name)
            continue
        grams = min(max(float(item.get("quantity") or item.get("grams") or 0), 0), REALISTIC_WEEKLY_CAP_G)
        for nutrient, value in profile.get("per_100g", {}).items():
            if nutrient in totals:
                totals[nutrient] += float(value) * grams / 100.0
                supported[nutrient] = True
    coverage = {}
    gaps = []
    for nutrient in TRACKED_NUTRIENTS:
        target = WEEKLY_RDA.get(nutrient)
        if not supported[nutrient] or target is None:
            continue
        pct = round(totals[nutrient] / target * 100, 1)
        coverage[nutrient] = {"achievable": round(totals[nutrient], 2), "target": target, "pct": pct}
        if pct < 50:
            gaps.append(nutrient)
    return {
        "label": "Up to this amount, if you cook optimally",
        "coverage": coverage,
        "structural_gaps": gaps,
        "missing_data": sorted(set(missing)),
        "computed_at": datetime.now(timezone.utc).isoformat(),
        "weekly_cap_g": REALISTIC_WEEKLY_CAP_G,
    }


def compute_structural_gaps_detail(
    structural_gaps: list[str],
    recipes: list[dict[str, Any]],
    inventory: list[dict[str, Any]],
    nutrient_db: dict[str, dict],
) -> list[dict[str, Any]]:
    """For each structural gap nutrient, identify which recipe would be unlocked
    and which specific ingredients are missing from inventory to make it.

    This output is the bridge between the backend shopping-list job and the
    Shopping Cart feature — every item in `missing_ingredients` maps directly
    to an "Add to Cart" action on the frontend.

    Returns a list of gap-detail objects:
    [
      {
        "nutrient": "iron_mg",
        "unlocks_recipe": "Palak Paneer",
        "missing_ingredients": [
          {"name": "spinach", "canonical_name": "spinach"}
        ]
      },
      ...
    ]

    Rules:
    - A recipe "fixes" a gap if it contributes ≥ 20 % of the daily RDA for
      that nutrient per serving (i.e. is a meaningful source, not a trace amount).
    - Among eligible recipes, prefer the one with the highest per-serving
      contribution for the gap nutrient.
    - `missing_ingredients` only lists what is NOT currently in inventory.
    - If all ingredients are already in inventory the recipe is already makeable —
      it still appears (the gap is structural because the user hasn't cooked it,
      not because they can't).
    """
    from app.data.rda_targets import DAILY_RDA

    # Build canonical inventory set for fast membership test
    inventory_canonical: set[str] = {
        _normalise(str(item.get("canonicalName") or item.get("name") or ""))
        for item in inventory
        if item.get("name")
    }

    results: list[dict[str, Any]] = []
    for nutrient in structural_gaps:
        daily_target = DAILY_RDA.get(nutrient)
        if daily_target is None:
            continue
        min_meaningful = daily_target * 0.20  # 20 % of daily RDA per serving

        best_recipe: dict[str, Any] | None = None
        best_amount = 0.0

        for recipe in recipes:
            nutrients_result = compute_recipe_nutrients(recipe, nutrient_db)
            per_serving = nutrients_result.get("totals", {}).get(nutrient, 0.0)
            if per_serving >= min_meaningful and per_serving > best_amount:
                best_amount = per_serving
                best_recipe = recipe

        if best_recipe is None:
            continue

        # Determine which ingredients are missing from current inventory
        missing_ingredients: list[dict[str, str]] = []
        raw_ingredients = _parse_ingredients(best_recipe)
        for ing in raw_ingredients:
            raw_name = str(ing.get("ingredient") or ing.get("name") or "").strip()
            if not raw_name:
                continue
            canon = _normalise(raw_name)
            if canon not in inventory_canonical:
                missing_ingredients.append({"name": raw_name, "canonical_name": canon})

        results.append({
            "nutrient": nutrient,
            "unlocks_recipe": best_recipe.get("name", ""),
            "recipe_id": best_recipe.get("id", ""),
            "per_serving_amount": round(best_amount, 2),
            "missing_ingredients": missing_ingredients,
        })

    return results


def _parse_ingredients(recipe: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract structured ingredient list from a recipe dict (handles both field names)."""
    import json
    raw = recipe.get("ingredientDetailsJson") or recipe.get("ingredientsJson") or recipe.get("ingredients")
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except (json.JSONDecodeError, ValueError):
            return []
    if isinstance(raw, list):
        return [item for item in raw if isinstance(item, dict)]
    return []
