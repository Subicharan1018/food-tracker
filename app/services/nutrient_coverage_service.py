"""Weekly inventory ceiling calculations for micronutrients."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from app.data.rda_targets import WEEKLY_RDA
from app.services.nutrient_calculator import TRACKED_NUTRIENTS

REALISTIC_WEEKLY_CAP_G = 1000.0  # transparent modelling cap, not a consumption prediction


def compute_weekly_nutrient_ceiling(inventory: list[dict[str, Any]], nutrient_db: dict[str, dict]) -> dict[str, Any]:
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
