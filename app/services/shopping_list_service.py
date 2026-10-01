"""Weekly shopping list: deterministic ceiling + gaps, with optional AI prose.

Used by both the Saturday scheduled job and the on-demand endpoint so the two
can never drift apart.
"""

from __future__ import annotations

import re
from datetime import date
from typing import Any

from app.config import logger
from app.services.nutrient_calculator import load_nutrient_profiles
from app.services.nutrient_coverage_service import (
    RecipeNutrientCache,
    aggregate_shopping_items,
    compute_structural_gaps_detail,
    compute_weekly_nutrient_ceiling,
)

_DIGIT = re.compile(r"\d")


def iso_week(today: date | None = None) -> str:
    today = today or date.today()
    iso = today.isocalendar()
    return f"{iso.year}-W{iso.week:02d}"


def prose_is_number_free(text: str | None) -> bool:
    """Rule 4 guard: AI prose may reason over numbers but never state one."""
    return bool(text and text.strip()) and not _DIGIT.search(text)


async def build_weekly_shopping_list(user_id: str, firestore, food_db=None, nemotron=None) -> dict[str, Any]:
    inventory = firestore.get_inventory(user_id)
    recipes = firestore.get_recipes(user_id)
    nutrient_db = load_nutrient_profiles()

    ceiling = compute_weekly_nutrient_ceiling(inventory, nutrient_db, food_db)
    cache = RecipeNutrientCache(nutrient_db, food_db)
    gaps_detail = compute_structural_gaps_detail(
        ceiling["structural_gaps"], recipes, inventory, nutrient_db, food_db, cache
    )
    payload: dict[str, Any] = {
        **ceiling,
        "structural_gaps_detail": gaps_detail,
        "shopping_list": aggregate_shopping_items(gaps_detail),
        "week": iso_week(),
        "user_id": user_id,
        "summary": None,
    }

    # Rule 5: no AI call unless a deterministic gap was found first.
    if nemotron is not None and gaps_detail:
        payload["summary"] = await _summarise(nemotron, gaps_detail)

    firestore.save_shopping_list(user_id, payload["week"], payload)
    return payload


async def _summarise(nemotron, gaps_detail: list[dict[str, Any]]) -> str | None:
    facts = [
        {
            "nutrient": g["nutrient"],
            "recipe": g["unlocks_recipe"],
            "buy": [i["name"] for i in g["missing_ingredients"]],
        }
        for g in gaps_detail
    ]
    system = (
        "You write one short shopping note for a home cook. You are given "
        "computed nutrient gaps and the recipe each purchase unlocks. "
        "Do not write any digits or quantities. Do not suggest any recipe or "
        "ingredient that is not in the facts."
    )
    prompt = f"Facts: {facts}\nWrite at most two sentences."
    try:
        text = (await nemotron.complete(system, prompt, max_tokens=90)).strip()
    except Exception as exc:  # AI prose is optional; the list stands without it.
        logger.warning("Shopping list summary skipped: %s", exc)
        return None
    if not prose_is_number_free(text):
        logger.warning("Shopping list summary discarded: contained a number")
        return None
    return text
