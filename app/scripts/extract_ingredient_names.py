"""
app/scripts/extract_ingredient_names.py

Pulls every unique ingredient name out of lib/core/local_db/recipe_seed_list.dart
(the structured ingredientsJson strings from Stage 0) and writes one name per
line to ingredient_names.txt — the input the IFCT conversion pipeline matches
against.

Usage:
    python -m app.scripts.extract_ingredient_names \
        lib/core/local_db/recipe_seed_list.dart \
        ingredient_names.txt
"""
import re
import sys
import json
from pathlib import Path

NAME_PATTERN = re.compile(r'"name"\s*:\s*"([^"]+)"')
JSON_BLOCK_PATTERN = re.compile(r'ingredientsJson:\s*jsonEncode\(\[(\s*[\s\S]*?)\s*\]\)', re.MULTILINE)


def clean_ingredient_string(item: str) -> str:
    cleaned = item.strip().lower()
    # Strip leading numbers/fractions and common measurement units
    cleaned = re.sub(r'^(?:\d+[\d\./\s]*(?:g|kg|ml|l|tbsp|tsp|cup|cups|piece|pieces|slice|slices|scoop|scoops|whisked|medium|large|small|clove|cloves|inch|pinch)?\s+)+', '', cleaned)
    # Strip parenthetical notes like (finely chopped), (dry pack), etc.
    cleaned = re.sub(r'\s*\([^)]*\)', '', cleaned)
    # Strip qualifiers at end
    cleaned = re.sub(r'\s+(?:to taste|finely chopped|chopped|sliced|grated|crushed|cooked|boiled|raw|for frying|fresh|dry)$', '', cleaned)
    cleaned = cleaned.strip('.,; ')
    return cleaned


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: python -m app.scripts.extract_ingredient_names <recipe_seed_list.dart> <output.txt>")
        sys.exit(1)

    src_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2])

    text = src_path.read_text(encoding="utf-8")
    names = {m.strip().lower() for m in NAME_PATTERN.findall(text)}

    if not names:
        # Extract from ingredientsJson blocks
        for block in JSON_BLOCK_PATTERN.findall(text):
            items = re.findall(r"'([^']+)'", block)
            for raw in items:
                cleaned = clean_ingredient_string(raw)
                if len(cleaned) >= 3 and not any(skip in cleaned for skip in ['salt &', 'salt to', 'water to', 'water for']):
                    names.add(cleaned)

    if not names:
        print(
            "No ingredient names found in source file."
        )
        sys.exit(1)

    out_path.write_text("\n".join(sorted(names)) + "\n", encoding="utf-8")
    print(f"Found {len(names)} unique ingredient names. Wrote {out_path}.")


if __name__ == "__main__":
    main()
