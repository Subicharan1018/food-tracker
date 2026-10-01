"""Deterministic intraday macro and micronutrient pace detection."""

from __future__ import annotations

import re
from typing import Any

from app.data.rda_targets import DAILY_RDA
from app.services.ingredient_identity import canonicalize
from app.services.nutrient_calculator import TRACKED_NUTRIENTS, _profile_from_ifct

CHECKPOINT_HOURS = (11, 14, 17, 21)
DEFAULT_DAILY_PROTEIN_G = 155.0


def expected_fraction_by_hour(hour: int) -> float:
    return max(0.0, min(1.0, (hour - 6) / 15.0))


_GRAMS_IN_UNIT = re.compile(r"(\d+(?:\.\d+)?)\s*(g|ml)\b", re.IGNORECASE)
_UNIT_GRAMS = {"g": 1.0, "gram": 1.0, "grams": 1.0, "ml": 1.0, "kg": 1000.0, "l": 1000.0}


def entry_grams(entry: dict[str, Any]) -> float | None:
    """Grams eaten for a diary entry, or None when the portion has no known weight.

    The app logs IFCT foods with ``portionUnit`` "g", so ``portionQty`` is grams.
    Count units that carry their weight ("egg (~55g)") are converted; anything
    else ("serving", "cup") is not guessed.
    """
    try:
        qty = float(entry.get("portionQty") if entry.get("portionQty") is not None else entry.get("portion_qty"))
    except (TypeError, ValueError):
        return None
    unit = str(entry.get("portionUnit") or entry.get("portion_unit") or "").strip().lower()
    if unit in _UNIT_GRAMS:
        return qty * _UNIT_GRAMS[unit]
    match = _GRAMS_IN_UNIT.search(unit)
    return qty * float(match.group(1)) if match else None


def diary_micronutrients(
    diary: list[dict[str, Any]],
    recipes: list[dict[str, Any]],
    food_db=None,
) -> dict[str, Any]:
    """Sum today's micronutrients from every entry that has a cited source.

    Order per entry: the IFCT row it was logged from (``foodItemId`` ifct_xxx),
    then a recipe with the same canonical name (its stored per-serving
    ``nutrients`` × servings).  Everything else is listed as uncounted — never
    treated as zero.  ``measured`` lists nutrients at least one counted entry
    actually reported, so an unreported nutrient isn't flagged as "behind".
    """
    recipe_by_name = {canonicalize(str(r.get("name") or "")): r for r in recipes}
    totals = {nutrient: 0.0 for nutrient in TRACKED_NUTRIENTS}
    measured: set[str] = set()
    counted: list[str] = []
    uncounted: list[str] = []

    for entry in diary:
        name = str(entry.get("foodName") or entry.get("food_name") or "").strip()
        values: dict[str, float] | None = None

        food_id = str(entry.get("foodItemId") or entry.get("food_item_id") or "")
        if food_id.startswith("ifct_") and food_db is not None:
            row = food_db.get_food_by_code(food_id[len("ifct_"):].upper())
            grams = entry_grams(entry)
            if row is not None and grams is not None:
                per_100g = _profile_from_ifct(row)["per_100g"]
                values = {k: v * grams / 100.0 for k, v in per_100g.items()}

        if values is None:
            recipe = recipe_by_name.get(canonicalize(name))
            if recipe and recipe.get("nutrients"):
                servings = float(entry.get("portionQty") or entry.get("portion_qty") or 1.0)
                values = {k: float(v) * servings for k, v in recipe["nutrients"].items()}

        if values is None:
            if name:
                uncounted.append(name)
            continue
        counted.append(name)
        for nutrient, value in values.items():
            if nutrient in totals:
                totals[nutrient] += value
                measured.add(nutrient)

    return {"totals": totals, "measured": measured, "counted": counted, "uncounted": uncounted}


def detect_gaps(
    today_diary: list[dict[str, Any]],
    recipes: list[dict[str, Any]],
    hour: int,
    protein_target_g: float = DEFAULT_DAILY_PROTEIN_G,
    food_db=None,
) -> dict[str, Any]:
    expected = expected_fraction_by_hour(hour)
    if not today_diary:
        return {"missed_logging": True} if hour >= 12 else {}
    issues: dict[str, Any] = {}
    protein = sum(float(entry.get("proteinG") or entry.get("protein_g") or 0.0) for entry in today_diary)
    expected_protein = protein_target_g * expected
    if protein < expected_protein * 0.7:
        issues["protein_behind"] = {"consumed": round(protein, 1), "expected": round(expected_protein, 1)}
    micros = diary_micronutrients(today_diary, recipes, food_db)
    gaps = {}
    for nutrient, target in DAILY_RDA.items():
        if target is None or nutrient not in micros["measured"]:
            continue
        required = target * expected
        consumed = micros["totals"][nutrient]
        if consumed < required * 0.7:
            gaps[nutrient] = {"consumed": round(consumed, 2), "expected": round(required, 2)}
    if gaps:
        issues["nutrient_gaps"] = gaps
    return issues


def gap_priority(nutrient_gaps: dict[str, dict[str, float]]) -> list[str]:
    """Nutrients ordered by how far behind pace they are (largest shortfall ratio first)."""
    def shortfall(item: tuple[str, dict[str, float]]) -> float:
        expected = float(item[1].get("expected") or 0.0)
        return 0.0 if expected <= 0 else 1.0 - float(item[1].get("consumed") or 0.0) / expected
    return [key for key, _ in sorted(nutrient_gaps.items(), key=shortfall, reverse=True)]
