"""Create an AI-assisted, human-reviewable Stage-0 seed migration file.

This script *never* edits the Dart seed list.  It sends each recipe's original
ingredient lines to the existing recipe ingestion agent, writes proposed
structured objects beside the originals, and marks every proposal
``review_required``.  A reviewer must approve the output before a separate
apply step is allowed.  This avoids silently treating an ambiguous phrase such
as "salt to taste" as a measurable food.

Usage:
    python -m app.scripts.prepare_seed_ingredient_review \
      lib/core/local_db/recipe_seed_list.dart seed_ingredient_review.json
"""

from __future__ import annotations

import asyncio
import json
import re
import sys
from pathlib import Path

from app.services.nemotron_service import nemotron_service
from app.services.recipe_ingestion_service import RecipeIngestionService
from app.services.food_db_service import food_db_service
from app.services.firestore_service import firestore_service

RECIPE_RE = re.compile(
    r"id:\s*'(?P<id>[^']+)'.*?ingredientsJson:\s*jsonEncode\(\[(?P<items>.*?)\]\)",
    re.DOTALL,
)
STRING_RE = re.compile(r"'((?:\\'|[^'])*)'")


async def main(source: Path, destination: Path) -> None:
    text = source.read_text(encoding="utf-8")
    service = RecipeIngestionService(food_db_service, firestore_service)
    review = []
    for match in RECIPE_RE.finditer(text):
        raw_items = [item.replace("\\'", "'") for item in STRING_RE.findall(match.group("items"))]
        raw_recipe = "Imported seed recipe\n" + "\n".join(f"- {item}" for item in raw_items)
        parsed = await service._parse_with_agent(raw_recipe, "snack", nemotron_service)
        review.append({
            "recipe_id": match.group("id"),
            "original_ingredients": raw_items,
            "proposed_ingredients": parsed["ingredients"],
            "review_required": True,
            "review_note": "Confirm every amount/unit; leave unknown amounts null.",
        })
    destination.write_text(json.dumps(review, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(review)} review records to {destination}; no seed data was changed.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python -m app.scripts.prepare_seed_ingredient_review <seed.dart> <review.json>")
    asyncio.run(main(Path(sys.argv[1]), Path(sys.argv[2])))
