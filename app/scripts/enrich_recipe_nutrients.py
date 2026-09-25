"""
One-time enrichment script — resolves missing ingredients via two-tier sourcing
(IFCT 2017 first, USDA FDC fallback) and writes confirmed results to
assets/nutrient_profiles.json.

Usage:
    python -m app.scripts.enrich_recipe_nutrients

Flags:
    --ingredient NAME    Resolve a single ingredient by name (skip Stage-0 sweep).
    --dry-run            Print proposed changes without writing to disk.

Human confirmation is REQUIRED for every USDA match — the script never
auto-selects a search result. "milk" alone returns dozens of USDA variants;
choosing the wrong one silently corrupts all downstream nutrient calculations.

IFCT matches (via food_db_service.search_foods) are also shown for confirmation;
they are safer because IFCT was purpose-built for Indian food composition.
"""
from __future__ import annotations

import argparse
import asyncio
import json
from datetime import date
from pathlib import Path

from app.services.food_db_service import food_db_service
from app.services.usda_fdc_client import get_food_nutrients, search_food

NUTRIENT_PROFILES_PATH = Path(__file__).resolve().parents[3] / "assets" / "nutrient_profiles.json"


def _load_profiles() -> dict:
    with NUTRIENT_PROFILES_PATH.open(encoding="utf-8") as f:
        return json.load(f)


def _save_profiles(profiles: dict) -> None:
    with NUTRIENT_PROFILES_PATH.open("w", encoding="utf-8") as f:
        json.dump(profiles, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved to {NUTRIENT_PROFILES_PATH}")


def _normalise(name: str) -> str:
    return " ".join(name.lower().replace("_", " ").split())


async def resolve_via_ifct(name: str) -> dict | None:
    """Try IFCT first — show matches for human confirmation."""
    candidates = food_db_service.search_foods(name, limit=5)
    if not candidates:
        print(f"  IFCT: no results for '{name}'")
        return None
    print(f"\n  IFCT candidates for '{name}':")
    for i, c in enumerate(candidates):
        print(f"    [{i}] {c.get('name')} (code: {c.get('code')}) — "
              f"iron {c.get('iron_mg', '?')} mg, calcium {c.get('calcium_mg', '?')} mg")
    choice = input("  Select index to use IFCT result (or Enter to try USDA instead): ").strip()
    if choice.isdigit() and int(choice) < len(candidates):
        food = candidates[int(choice)]
        return {
            "per_100g": _extract_ifct_nutrients(food),
            "source": "IFCT 2017",
            "ifct_code": food.get("code"),
            "ifct_name": food.get("name"),
            "verified_date": date.today().isoformat(),
        }
    return None


def _extract_ifct_nutrients(food: dict) -> dict[str, float]:
    column_map = {
        "vitaminD_mcg": "vitamin_d_ug",
        "iron_mg": "iron_mg",
        "calcium_mg": "calcium_mg",
        "magnesium_mg": "magnesium_mg",
        "zinc_mg": "zinc_mg",
        "potassium_mg": "potassium_mg",
        "folate_mcg": "folate_b9_ug",
    }
    result: dict[str, float] = {}
    for our_key, col in column_map.items():
        val = food.get(col)
        if val is not None:
            try:
                result[our_key] = float(val)
            except (TypeError, ValueError):
                pass
    return result


async def resolve_via_usda(name: str) -> dict | None:
    """Try USDA FDC — show candidates, require human to select."""
    candidates = await search_food(name, page_size=8)
    if not candidates:
        print(f"  USDA: no results for '{name}'")
        return None
    print(f"\n  USDA FDC candidates for '{name}':")
    for i, c in enumerate(candidates):
        print(f"    [{i}] {c.get('description')} "
              f"(FDC #{c.get('fdcId')}, type: {c.get('dataType')})")
    choice = input("  Select index (or 's' to skip and mark UNAVAILABLE): ").strip()
    if choice.lower() == "s" or not choice.isdigit():
        return None
    idx = int(choice)
    if idx >= len(candidates):
        print("  Invalid index — skipping.")
        return None
    selected = candidates[idx]
    fdc_id = selected["fdcId"]
    print(f"  Fetching FDC #{fdc_id} …")
    profile = await get_food_nutrients(fdc_id)
    profile["verified_date"] = date.today().isoformat()
    return profile


async def resolve_ingredient(name: str, profiles: dict, dry_run: bool) -> bool:
    """Resolve one ingredient name through IFCT then USDA. Returns True if resolved."""
    canon = _normalise(name)
    existing = profiles.get(canon, {})
    if existing.get("source") not in (None, "", "UNAVAILABLE"):
        print(f"  ✓ Already resolved: '{canon}' → {existing.get('source')}")
        return True

    print(f"\n{'─'*55}")
    print(f"  Resolving: '{canon}'")

    # Tier 1: IFCT
    profile = await resolve_via_ifct(canon)

    # Tier 2: USDA fallback
    if profile is None:
        profile = await resolve_via_usda(canon)

    # Neither found
    if profile is None:
        mark = input("  Mark as UNAVAILABLE? (y/n): ").strip().lower()
        if mark == "y":
            profile = {
                "source": "UNAVAILABLE",
                "per_100g": {},
                "verified_date": date.today().isoformat(),
                "note": "Not found in IFCT 2017 or USDA FDC after manual search.",
            }
        else:
            print("  Skipped.")
            return False

    print(f"\n  Profile to write for '{canon}':")
    print(f"  {json.dumps(profile, indent=4)}")
    confirm = input("  Write this entry? (y/n): ").strip().lower()
    if confirm != "y":
        print("  Skipped.")
        return False

    if not dry_run:
        profiles[canon] = profile
        _save_profiles(profiles)
    else:
        print("  [dry-run] Would write — not saved.")
    return True


async def main(ingredient: str | None = None, dry_run: bool = False) -> None:
    profiles = _load_profiles()

    if ingredient:
        # Single-ingredient mode
        await resolve_ingredient(ingredient, profiles, dry_run)
        return

    # Stage-0 sweep mode: report all ingredients missing from profiles
    print("Running Stage-0 sweep against nutrient_profiles.json …")
    print("(Supply --ingredient NAME to resolve a specific ingredient instead.)\n")
    print("Currently unresolved keys in nutrient_profiles.json:")
    unresolved = [
        k for k, v in profiles.items()
        if k != "_meta" and v.get("source") in (None, "", "UNAVAILABLE")
    ]
    if not unresolved:
        print("  None — all present entries are resolved. ✓")
        print("\nTo resolve a new ingredient not yet in the file:")
        print("  python -m app.scripts.enrich_recipe_nutrients --ingredient 'oats'")
        return
    for u in unresolved:
        print(f"  • {u}")
    print()
    for u in unresolved:
        await resolve_ingredient(u, profiles, dry_run)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Two-tier nutrient enrichment: IFCT → USDA FDC")
    parser.add_argument("--ingredient", type=str, default=None,
                        help="Resolve a single ingredient name (skip the sweep)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print proposed changes without writing to disk")
    args = parser.parse_args()
    asyncio.run(main(ingredient=args.ingredient, dry_run=args.dry_run))
