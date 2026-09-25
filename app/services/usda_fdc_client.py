"""
USDA FoodData Central client — fallback nutrient source when IFCT 2017 doesn't
cover an ingredient.

Priority chain:
  1. IFCT 2017 (app/data/ifct2017.db)  — primary, most accurate for Indian foods
  2. USDA FDC (this module)             — fallback for imports not in IFCT
  3. UNAVAILABLE                        — only when neither source has the food

Real API calls only. FDC IDs are real USDA numeric IDs — the mapping below was
verified against the live nutrient list at https://fdc.nal.usda.gov/food-details
Do NOT trust these IDs without confirming against a real API response.

Free API key: https://api.data.gov/signup/
"""
from __future__ import annotations

import httpx
from app.config import settings, logger

FDC_BASE = "https://api.nal.usda.gov/fdc/v1"

# USDA nutrient IDs verified against FDC API responses.
# Omega-3 is deliberately NOT a single ID — it is the sum of three fatty acids:
#   1404 = ALA (alpha-linolenic acid, 18:3 n-3)
#   1278 = EPA (eicosapentaenoic acid, 20:5 n-3)
#   1272 = DHA (docosahexaenoic acid, 22:6 n-3)
# See USDA_OMEGA3_IDS below; all three must be fetched and summed.
USDA_NUTRIENT_IDS: dict[str, int] = {
    "vitaminD_mcg": 1114,
    "b12_mcg":      1178,
    "iron_mg":      1089,
    "calcium_mg":   1087,
    "magnesium_mg": 1090,
    "zinc_mg":      1095,
    "potassium_mg": 1092,
    "folate_mcg":   1177,
}

# These three are summed into "omega3_g"
USDA_OMEGA3_IDS: tuple[int, ...] = (1404, 1278, 1272)


async def search_food(query: str, page_size: int = 5) -> list[dict]:
    """Search USDA FDC for a food name. Returns up to `page_size` candidate matches.

    IMPORTANT: Always present candidates to a human for confirmation before
    writing any result to nutrient_profiles.json. Food search is ambiguous —
    "milk" alone returns dozens of variants (whole, skim, buffalo, condensed …).
    Auto-selecting the first result is prohibited.
    """
    if not query or not query.strip():
        return []
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.get(
                f"{FDC_BASE}/foods/search",
                params={
                    "query": query.strip(),
                    "api_key": settings.usda_fdc_api_key,
                    "pageSize": page_size,
                    # Prefer Foundation and SR Legacy foods: they have the most
                    # complete nutrient panels and are not brand-specific.
                    "dataType": "Foundation,SR Legacy",
                },
            )
            resp.raise_for_status()
            return resp.json().get("foods", [])
        except httpx.HTTPStatusError as e:
            logger.error("USDA FDC search HTTP error for '%s': %s", query, e)
            return []
        except Exception as e:
            logger.error("USDA FDC search error for '%s': %s", query, e)
            return []


async def get_food_nutrients(fdc_id: int) -> dict:
    """Fetch full nutrient detail for one FDC ID.

    Returns a profile dict compatible with nutrient_profiles.json schema:
    {
        "per_100g": { "iron_mg": 2.7, ... },  # only nutrients found in the response
        "source": "USDA FDC #12345",
        "usda_description": "Spinach, raw",
        "usda_fdc_id": 12345,
        "verified_date": "<ISO date this entry was human-confirmed>",
    }

    Omega-3 is built by summing ALA + EPA + DHA nutrient IDs.
    Any nutrient absent from the response is simply not included in per_100g —
    it is never assumed to be zero.
    """
    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.get(
                f"{FDC_BASE}/food/{fdc_id}",
                params={"api_key": settings.usda_fdc_api_key},
            )
            resp.raise_for_status()
            data = resp.json()
        except httpx.HTTPStatusError as e:
            logger.error("USDA FDC get-food HTTP error for FDC#%s: %s", fdc_id, e)
            return {"source": "UNAVAILABLE", "per_100g": {}}
        except Exception as e:
            logger.error("USDA FDC get-food error for FDC#%s: %s", fdc_id, e)
            return {"source": "UNAVAILABLE", "per_100g": {}}

    per_100g: dict[str, float] = {}
    omega3_sum = 0.0
    omega3_found = False

    for nutrient in data.get("foodNutrients", []):
        nid = nutrient.get("nutrient", {}).get("id")
        amount = nutrient.get("amount")
        if amount is None:
            continue

        # Single-ID nutrients
        for our_key, usda_id in USDA_NUTRIENT_IDS.items():
            if nid == usda_id:
                per_100g[our_key] = float(amount)

        # Omega-3 components — must be summed
        if nid in USDA_OMEGA3_IDS:
            omega3_sum += float(amount)
            omega3_found = True

    if omega3_found:
        # USDA reports fatty acids in grams per 100 g food
        per_100g["omega3_g"] = round(omega3_sum, 4)

    return {
        "per_100g": per_100g,
        "source": f"USDA FDC #{fdc_id}",
        "usda_fdc_id": fdc_id,
        "usda_description": data.get("description", ""),
        # Caller must fill in "verified_date" after human confirmation
    }
