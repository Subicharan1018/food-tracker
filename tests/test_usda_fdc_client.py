"""
Tests for app/services/usda_fdc_client.py

All HTTP calls are mocked — no real network traffic is made.
The fixtures use realistic USDA FDC API response shapes so the mapping
logic is validated against the actual JSON format the API returns.
"""
from __future__ import annotations

import pytest
import httpx
import respx

from app.services.usda_fdc_client import (
    FDC_BASE,
    USDA_NUTRIENT_IDS,
    USDA_OMEGA3_IDS,
    get_food_nutrients,
    search_food,
)


# ── Fixtures ──────────────────────────────────────────────────────────────────

MOCK_SEARCH_RESPONSE = {
    "foods": [
        {"fdcId": 168917, "description": "Oats, raw", "dataType": "SR Legacy"},
        {"fdcId": 168462, "description": "Oats, instant, unenriched", "dataType": "SR Legacy"},
    ]
}

# Realistic FDC API food-detail response shape (trimmed to tested nutrients)
MOCK_FOOD_DETAIL_OATS = {
    "fdcId": 168917,
    "description": "Oats, raw",
    "foodNutrients": [
        # Iron
        {"nutrient": {"id": 1089, "name": "Iron, Fe"}, "amount": 3.66},
        # Calcium
        {"nutrient": {"id": 1087, "name": "Calcium, Ca"}, "amount": 52.0},
        # Magnesium
        {"nutrient": {"id": 1090, "name": "Magnesium, Mg"}, "amount": 138.0},
        # Zinc
        {"nutrient": {"id": 1095, "name": "Zinc, Zn"}, "amount": 3.64},
        # Potassium
        {"nutrient": {"id": 1092, "name": "Potassium, K"}, "amount": 362.0},
        # Folate
        {"nutrient": {"id": 1177, "name": "Folate, total"}, "amount": 56.0},
        # Vitamin D — oats have none; this nutrient is deliberately absent
        # B12 — absent in oats; should not appear in output
        # ALA (omega-3 component 1)
        {"nutrient": {"id": 1404, "name": "18:3 n-3 c,c,c (ALA)"}, "amount": 0.111},
        # EPA (omega-3 component 2)
        {"nutrient": {"id": 1278, "name": "20:5 n-3 (EPA)"}, "amount": 0.0},
        # DHA (omega-3 component 3)
        {"nutrient": {"id": 1272, "name": "22:6 n-3 (DHA)"}, "amount": 0.0},
        # A nutrient that is NOT in our tracked set — must be ignored
        {"nutrient": {"id": 9999, "name": "Unknown nutrient"}, "amount": 999.0},
    ],
}

MOCK_FOOD_DETAIL_SALMON = {
    "fdcId": 175167,
    "description": "Fish, salmon, Atlantic, raw",
    "foodNutrients": [
        {"nutrient": {"id": 1178, "name": "Vitamin B-12"}, "amount": 3.18},
        {"nutrient": {"id": 1089, "name": "Iron, Fe"}, "amount": 0.34},
        # ALA + EPA + DHA for omega-3 sum
        {"nutrient": {"id": 1404, "name": "18:3 n-3"}, "amount": 0.172},
        {"nutrient": {"id": 1278, "name": "20:5 n-3 (EPA)"}, "amount": 0.587},
        {"nutrient": {"id": 1272, "name": "22:6 n-3 (DHA)"}, "amount": 1.429},
        # Vitamin D in salmon
        {"nutrient": {"id": 1114, "name": "Vitamin D (D2 + D3)"}, "amount": 11.0},
    ],
}


# ── search_food tests ─────────────────────────────────────────────────────────

@pytest.mark.asyncio
@respx.mock
async def test_search_food_returns_candidates():
    respx.get(f"{FDC_BASE}/foods/search").mock(
        return_value=httpx.Response(200, json=MOCK_SEARCH_RESPONSE)
    )
    results = await search_food("oats")
    assert len(results) == 2
    assert results[0]["fdcId"] == 168917
    assert results[0]["description"] == "Oats, raw"


@pytest.mark.asyncio
@respx.mock
async def test_search_food_empty_query_returns_empty():
    results = await search_food("")
    assert results == []


@pytest.mark.asyncio
@respx.mock
async def test_search_food_http_error_returns_empty():
    respx.get(f"{FDC_BASE}/foods/search").mock(
        return_value=httpx.Response(403, json={"error": "OVER_RATE_LIMIT"})
    )
    results = await search_food("oats")
    assert results == []


# ── get_food_nutrients tests ──────────────────────────────────────────────────

@pytest.mark.asyncio
@respx.mock
async def test_get_food_nutrients_oats_correct_per100g():
    respx.get(f"{FDC_BASE}/food/168917").mock(
        return_value=httpx.Response(200, json=MOCK_FOOD_DETAIL_OATS)
    )
    profile = await get_food_nutrients(168917)

    assert profile["source"] == "USDA FDC #168917"
    assert profile["usda_fdc_id"] == 168917
    assert profile["usda_description"] == "Oats, raw"

    per = profile["per_100g"]
    assert per["iron_mg"] == 3.66
    assert per["calcium_mg"] == 52.0
    assert per["magnesium_mg"] == 138.0
    assert per["zinc_mg"] == 3.64
    assert per["potassium_mg"] == 362.0
    assert per["folate_mcg"] == 56.0

    # Vitamin D and B12 are absent in oats — must NOT appear as 0, must be absent
    assert "vitaminD_mcg" not in per
    assert "b12_mcg" not in per


@pytest.mark.asyncio
@respx.mock
async def test_omega3_is_summed_from_three_fatty_acid_ids():
    """ALA(0.111) + EPA(0.0) + DHA(0.0) = 0.111 g for oats."""
    respx.get(f"{FDC_BASE}/food/168917").mock(
        return_value=httpx.Response(200, json=MOCK_FOOD_DETAIL_OATS)
    )
    profile = await get_food_nutrients(168917)
    assert abs(profile["per_100g"]["omega3_g"] - 0.111) < 0.0001


@pytest.mark.asyncio
@respx.mock
async def test_omega3_salmon_sums_all_three_components():
    """ALA(0.172) + EPA(0.587) + DHA(1.429) = 2.188 g for salmon."""
    respx.get(f"{FDC_BASE}/food/175167").mock(
        return_value=httpx.Response(200, json=MOCK_FOOD_DETAIL_SALMON)
    )
    profile = await get_food_nutrients(175167)
    expected_omega3 = 0.172 + 0.587 + 1.429
    assert abs(profile["per_100g"]["omega3_g"] - expected_omega3) < 0.0001
    # Salmon-specific nutrients
    assert profile["per_100g"]["b12_mcg"] == 3.18
    assert profile["per_100g"]["vitaminD_mcg"] == 11.0


@pytest.mark.asyncio
@respx.mock
async def test_unknown_usda_nutrient_ids_are_ignored():
    """Nutrient ID 9999 in the mock must not appear in per_100g output."""
    respx.get(f"{FDC_BASE}/food/168917").mock(
        return_value=httpx.Response(200, json=MOCK_FOOD_DETAIL_OATS)
    )
    profile = await get_food_nutrients(168917)
    # Only tracked keys should be present
    for key in profile["per_100g"]:
        assert key in list(USDA_NUTRIENT_IDS.keys()) + ["omega3_g"], \
            f"Unexpected key '{key}' in per_100g output"


@pytest.mark.asyncio
@respx.mock
async def test_get_food_nutrients_http_error_returns_unavailable():
    respx.get(f"{FDC_BASE}/food/99999").mock(
        return_value=httpx.Response(404, json={"error": "not found"})
    )
    profile = await get_food_nutrients(99999)
    assert profile["source"] == "UNAVAILABLE"
    assert profile["per_100g"] == {}


@pytest.mark.asyncio
@respx.mock
async def test_nutrient_with_none_amount_is_excluded():
    """If USDA returns a nutrient entry with amount=null, it must not appear."""
    mock_data = {
        "fdcId": 12345,
        "description": "Test food",
        "foodNutrients": [
            {"nutrient": {"id": 1089, "name": "Iron, Fe"}, "amount": None},
            {"nutrient": {"id": 1087, "name": "Calcium, Ca"}, "amount": 50.0},
        ],
    }
    respx.get(f"{FDC_BASE}/food/12345").mock(
        return_value=httpx.Response(200, json=mock_data)
    )
    profile = await get_food_nutrients(12345)
    assert "iron_mg" not in profile["per_100g"]
    assert profile["per_100g"]["calcium_mg"] == 50.0
