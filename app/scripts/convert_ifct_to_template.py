"""
app/scripts/convert_ifct_to_template.py

Takes:
  - ingredient_names.txt      (from extract_ingredient_names.py)
  - ifct_column_mapping.json  (from discover_ifct_columns.py, hand-confirmed)
  - the cloned ifct2017 repo's compositions/index.csv

...and produces a CSV in the exact shape of nutrient_profiles_template.csv,
pre-filled for every ingredient it could confidently name-match against the
IFCT compositions table.

Nothing here is auto-accepted silently. Every row this script fills in is
still marked "AUTO-MATCHED — VERIFY" in the notes column — per Stage 0's own
rule, an automated match on food names gets one manual spot-check pass before
it's trusted, because "chicken breast" matching the wrong "Chicken, ..." row
is exactly the kind of error that's easy to make and expensive to leave in.

Anything with no confident match gets a blank row with its nearest
candidates listed, so you know what to type in by hand instead of guessing.

Usage:
    python -m app.scripts.convert_ifct_to_template \
        ingredient_names.txt \
        ifct_column_mapping.json \
        /path/to/cloned/ifct2017/compositions/index.csv \
        nutrient_profiles_prefilled.csv
"""
import csv
import json
import sys
from datetime import date
from pathlib import Path

NUTRIENT_FIELDS = [
    "vitaminD_mcg", "b12_mcg", "iron_mg", "calcium_mg",
    "magnesium_mg", "zinc_mg", "potassium_mg", "omega3_g", "folate_mcg",
]
OUTPUT_COLUMNS = [
    "ingredient_name", *NUTRIENT_FIELDS, "source", "verified_date", "notes",
]

MATCH_THRESHOLD = 0.35  # Jaccard token overlap — below this, don't suggest as confident


def tokenize(name: str) -> set[str]:
    return {t.strip(",.()") for t in name.lower().replace("-", " ").split() if t.strip(",.()")}


def jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def best_matches(ingredient: str, compositions: list[dict], top_n: int = 3) -> list[tuple[dict, float]]:
    target = tokenize(ingredient)
    scored = [(row, jaccard(target, tokenize(row.get("name", "")))) for row in compositions]
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:top_n]


def extract_value(row: dict, entry: dict) -> float | None:
    if not entry or entry.get("code") is None:
        return None
    code = entry.get("code")
    factor = entry.get("factor_to_target_unit")
    if code == "CHOOSE_FROM_ABOVE" or factor == "VERIFY_AGAINST_SAMPLES_ABOVE":
        raise ValueError(f"Mapping entry not confirmed yet: {entry}")
    raw = row.get(code)
    if raw in (None, "", "NA", "Tr", "n/a"):
        return None
    try:
        return float(raw) * float(factor)
    except ValueError:
        return None


def main() -> None:
    if len(sys.argv) != 5:
        print("Usage: python -m app.scripts.convert_ifct_to_template "
              "<ingredient_names.txt> <ifct_column_mapping.json> "
              "<compositions/index.csv> <output.csv>")
        sys.exit(1)

    names_path, mapping_path, comp_path, out_path = (Path(a) for a in sys.argv[1:])

    ingredient_names = [l.strip() for l in names_path.read_text(encoding="utf-8").splitlines() if l.strip()]
    mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
    with comp_path.open(newline="", encoding="utf-8") as f:
        compositions = list(csv.DictReader(f))

    # Fail loudly if mapping has unconfirmed placeholders
    unresolved = [k for k, v in mapping.items() if v.get("code") == "CHOOSE_FROM_ABOVE"
                  or v.get("factor_to_target_unit") == "VERIFY_AGAINST_SAMPLES_ABOVE"]
    if unresolved:
        print(f"ifct_column_mapping.json still has unconfirmed entries: {unresolved}")
        print("Go confirm these against discover_ifct_columns.py's sample output first.")
        sys.exit(1)

    today = date.today().isoformat()
    rows_out = []
    matched, unmatched = 0, 0

    for name in ingredient_names:
        candidates = best_matches(name, compositions)
        top_row, top_score = candidates[0] if candidates else (None, 0.0)

        if not top_row or top_score < MATCH_THRESHOLD:
            unmatched += 1
            candidate_str = "; ".join(f"{r.get('name')} ({s:.2f})" for r, s in candidates if s > 0)
            rows_out.append({
                "ingredient_name": name,
                **{f: "" for f in NUTRIENT_FIELDS},
                "source": "",
                "verified_date": "",
                "notes": f"NO CONFIDENT MATCH — nearest candidates: {candidate_str or 'none'}",
            })
            continue

        values = {}
        for nutrient in ["vitaminD_mcg", "b12_mcg", "iron_mg", "calcium_mg",
                          "magnesium_mg", "zinc_mg", "potassium_mg", "folate_mcg"]:
            v = extract_value(top_row, mapping.get(nutrient, {}))
            values[nutrient] = round(v, 4) if v is not None else ""

        ala = extract_value(top_row, mapping.get("omega3_ala", {})) or 0.0
        epa = extract_value(top_row, mapping.get("omega3_epa", {})) or 0.0
        dha = extract_value(top_row, mapping.get("omega3_dha", {})) or 0.0
        tot_omega = ala + epa + dha
        values["omega3_g"] = round(tot_omega, 4) if tot_omega > 0 else ""

        matched += 1
        rows_out.append({
            "ingredient_name": name,
            **{f: values.get(f, "") for f in NUTRIENT_FIELDS},
            "source": "IFCT 2017",
            "verified_date": today,
            "notes": (f"AUTO-MATCHED — VERIFY: matched '{name}' to IFCT '{top_row.get('name')}' "
                      f"(code {top_row.get('code')}, token-overlap score {top_score:.2f})"),
        })

    with out_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows_out)

    print(f"{matched} auto-matched (every row marked VERIFY, review before importing), "
          f"{unmatched} need manual entry.")
    print(f"Wrote {out_path}.")
    print("\nNext: open it, skim every 'AUTO-MATCHED' row against the IFCT name it picked, "
          "fill in the unmatched rows by hand, then run:")
    print(f"  python -m app.scripts.import_nutrient_profiles {out_path}")


if __name__ == "__main__":
    main()
