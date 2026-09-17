"""Deterministic, source-aware recipe micronutrient computation.

No language model is involved here.  Missing food matches, unknown portions,
and nutrients not supplied by IFCT are returned as coverage gaps instead of
being converted to zero-valued claims.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from app.data.unit_conversions import (
    INGREDIENT_UNIT_WEIGHTS_G,
    PIECE_WEIGHTS_G,
    UNIT_TO_GRAMS,
)

TRACKED_NUTRIENTS = (
    "vitaminD_mcg", "b12_mcg", "iron_mg", "calcium_mg",
    "magnesium_mg", "zinc_mg", "potassium_mg", "omega3_g", "folate_mcg",
)

IFCT_COLUMN_MAP = {
    "vitaminD_mcg": "vitamin_d_ug",
    "iron_mg": "iron_mg",
    "calcium_mg": "calcium_mg",
    "magnesium_mg": "magnesium_mg",
    "zinc_mg": "zinc_mg",
    "potassium_mg": "potassium_mg",
    "folate_mcg": "folate_b9_ug",
}


def load_nutrient_profiles(path: str | Path | None = None) -> dict[str, dict]:
    source = Path(path) if path else Path(__file__).resolve().parents[2] / "assets" / "nutrient_profiles.json"
    with source.open(encoding="utf-8") as handle:
        return json.load(handle)


def _normalise(value: Any) -> str:
    return " ".join(str(value or "").lower().replace("_", " ").split())


def _to_grams(amount: Any, unit: Any, ingredient_name: str, explicit_grams: Any = None) -> float | None:
    """Return a reviewable gram amount or ``None`` when it cannot be known."""
    try:
        if explicit_grams is not None:
            return float(explicit_grams)
        quantity = float(amount)
    except (TypeError, ValueError):
        return None
    if quantity < 0:
        return None
    name, canonical_unit = _normalise(ingredient_name), _normalise(unit)
    specific = INGREDIENT_UNIT_WEIGHTS_G.get((name, canonical_unit))
    if specific is not None:
        return quantity * specific
    if canonical_unit in {"piece", "pieces", "", "small", "medium", "large"}:
        weight = PIECE_WEIGHTS_G.get(name)
        return quantity * weight if weight is not None else None
    factor = UNIT_TO_GRAMS.get(canonical_unit)
    return quantity * factor if factor is not None else None


def _structured_ingredients(recipe: dict[str, Any]) -> list[dict[str, Any]] | None:
    """Read only the structured schema; legacy display-string lists are rejected."""
    raw = recipe.get("ingredientDetailsJson") or recipe.get("ingredientsJson") or recipe.get("ingredients")
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except json.JSONDecodeError:
            return None
    if not isinstance(raw, list) or any(not isinstance(item, dict) for item in raw):
        return None
    return raw


def _profile_from_ifct(food: dict[str, Any]) -> dict[str, Any]:
    values: dict[str, float] = {}
    unavailable: list[str] = []
    for nutrient in TRACKED_NUTRIENTS:
        column = IFCT_COLUMN_MAP.get(nutrient)
        value = food.get(column) if column else None
        if value is None:
            unavailable.append(nutrient)
            continue
        values[nutrient] = float(value)
    return {
        "per_100g": values,
        "source": "IFCT 2017",
        "verified_date": "2017-01-01",
        "unavailable_nutrients": unavailable,
    }


def compute_recipe_nutrients(recipe: dict[str, Any], nutrient_db: dict[str, dict], food_db=None) -> dict[str, Any]:
    """Compute per-serving totals and disclose every uncomputed input."""
    ingredients = _structured_ingredients(recipe)
    if ingredients is None:
        return {
            "error": "ingredientsJson is not a structured ingredient array",
            "totals": {}, "missing_data": ["structured ingredients pending migration"],
            "unavailable_nutrients": list(TRACKED_NUTRIENTS), "source": [],
        }
    totals = {nutrient: 0.0 for nutrient in TRACKED_NUTRIENTS}
    available = {nutrient: False for nutrient in TRACKED_NUTRIENTS}
    missing_data: list[str] = []
    unavailable: set[str] = set()
    sources: set[str] = set()
    servings = float(recipe.get("servings") or 1.0)
    servings = servings if servings > 0 else 1.0

    for item in ingredients:
        name = str(item.get("ingredient") or item.get("name") or "").strip()
        if not name:
            continue
        grams = _to_grams(item.get("amount"), item.get("unit"), name, item.get("grams"))
        if grams is None:
            missing_data.append(f"{name} (unknown portion)")
            continue
        profile = nutrient_db.get(_normalise(name))
        if profile is None and food_db is not None:
            code = item.get("food_code") or item.get("foodCode")
            food = food_db.get_food_by_code(str(code)) if code else None
            if food is None:
                candidates = food_db.search_foods(name, limit=1)
                food = candidates[0] if candidates else None
            if food is not None:
                profile = _profile_from_ifct(food)
        if not profile or profile.get("source") == "UNAVAILABLE":
            missing_data.append(name)
            continue
        sources.add(str(profile.get("source", "Unknown source")))
        values = profile.get("per_100g", {})
        for nutrient in TRACKED_NUTRIENTS:
            if nutrient not in values:
                unavailable.add(nutrient)
                continue
            totals[nutrient] += float(values[nutrient]) * grams / 100.0 / servings
            available[nutrient] = True

    return {
        "totals": {key: round(value, 2) for key, value in totals.items() if available[key]},
        "missing_data": sorted(set(missing_data)),
        "unavailable_nutrients": sorted(set(TRACKED_NUTRIENTS) - {key for key, ok in available.items() if ok} | unavailable),
        "source": sorted(sources),
    }
