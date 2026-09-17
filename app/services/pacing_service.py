"""Deterministic intraday macro and micronutrient pace detection."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from app.data.rda_targets import DAILY_RDA
from app.services.nutrient_calculator import TRACKED_NUTRIENTS

CHECKPOINT_HOURS = (11, 14, 17, 21)
DEFAULT_DAILY_PROTEIN_G = 155.0


def expected_fraction_by_hour(hour: int) -> float:
    return max(0.0, min(1.0, (hour - 6) / 15.0))


def _recipe_lookup(recipes: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(recipe.get("name") or "").strip().lower(): recipe for recipe in recipes}


def _daily_nutrients(diary: list[dict[str, Any]], recipes: list[dict[str, Any]]) -> dict[str, float]:
    recipe_by_name = _recipe_lookup(recipes)
    totals = {nutrient: 0.0 for nutrient in TRACKED_NUTRIENTS}
    for entry in diary:
        recipe = recipe_by_name.get(str(entry.get("foodName") or entry.get("food_name") or "").strip().lower())
        if not recipe:
            continue
        portions = float(entry.get("portionQty") or entry.get("portion_qty") or 1.0)
        for nutrient, value in (recipe.get("nutrients") or {}).items():
            if nutrient in totals:
                totals[nutrient] += float(value) * portions
    return totals


def detect_gaps(today_diary: list[dict[str, Any]], recipes: list[dict[str, Any]], hour: int, protein_target_g: float = DEFAULT_DAILY_PROTEIN_G) -> dict[str, Any]:
    expected = expected_fraction_by_hour(hour)
    if not today_diary:
        return {"missed_logging": True} if hour >= 12 else {}
    issues: dict[str, Any] = {}
    protein = sum(float(entry.get("proteinG") or entry.get("protein_g") or 0.0) for entry in today_diary)
    expected_protein = protein_target_g * expected
    if protein < expected_protein * 0.7:
        issues["protein_behind"] = {"consumed": round(protein, 1), "expected": round(expected_protein, 1)}
    nutrients = _daily_nutrients(today_diary, recipes)
    gaps = {}
    for nutrient, target in DAILY_RDA.items():
        if target is None:
            continue
        required = target * expected
        if nutrients[nutrient] < required * 0.7:
            gaps[nutrient] = {"consumed": round(nutrients[nutrient], 2), "expected": round(required, 2)}
    if gaps:
        issues["nutrient_gaps"] = gaps
    return issues
