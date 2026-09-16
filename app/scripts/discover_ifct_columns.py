"""
app/scripts/discover_ifct_columns.py

The IFCT compositions table stores each nutrient as its own column, named by
a short code (e.g. 'vitc' for vitamin C) — not by our nutrient names. Before
any values can be pulled out, we need to know which code(s) in *this specific
dataset* correspond to our 9 tracked nutrients.

This script does NOT guess the codes. It searches columns/index.csv (name +
tags) for keyword matches per nutrient, then — for every candidate — prints
its raw value for three well-known foods (egg, chicken breast, milk) next to
its declared unit/conversion factor from representations/index.csv, so you
can eyeball whether the numbers look right (e.g. "does this egg row really
show ~1.1 for vitamin D once the factor is applied?") before committing to a
mapping. This is the human-verification step the rest of the pipeline
depends on — do not skip it and hardcode a guessed code.

Usage:
    python -m app.scripts.discover_ifct_columns /path/to/cloned/ifct2017

Output:
    Prints candidates to stdout AND writes ifct_column_mapping.template.json
    — a skeleton you fill in by hand (one confirmed code per nutrient, plus
    the multiply-by factor to reach our target unit) before running
    convert_ifct_to_template.py.
"""
import csv
import json
import sys
from pathlib import Path

# keyword -> our nutrient key. Omega-3 gets three keyword groups because it's
# a sum of three fatty acids, not one column.
SEARCH_TERMS = {
    "vitaminD_mcg":  ["vitamin d", "cholecalciferol", "ergocalciferol", "calciferol"],
    "b12_mcg":       ["vitamin b12", "cobalamin", "b-12", "b 12"],
    "iron_mg":       ["iron"],
    "calcium_mg":    ["calcium"],
    "magnesium_mg":  ["magnesium"],
    "zinc_mg":       ["zinc"],
    "potassium_mg":  ["potassium"],
    "folate_mcg":    ["folate", "folic acid", "vitamin b9"],
    "omega3_ala":    ["linolenic", "alpha-linolenic", "18:3n-3", "18:3 n-3"],
    "omega3_epa":    ["eicosapentaenoic", "20:5n-3", "20:5 n-3"],
    "omega3_dha":    ["docosahexaenoic", "22:6n-3", "22:6 n-3"],
}

SAMPLE_FOODS = ["egg", "chicken breast", "milk, cow"]


def load_csv(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def find_column(rows: list[dict], key_field: str, name_field: str, tags_field: str, keywords: list[str]) -> list[dict]:
    matches = []
    for row in rows:
        haystack = f"{row.get(name_field, '')} {row.get(tags_field, '')}".lower()
        if any(kw in haystack for kw in keywords):
            matches.append(row)
    return matches


def sample_values(compositions: list[dict], code: str) -> dict:
    out = {}
    for food_kw in SAMPLE_FOODS:
        for row in compositions:
            if food_kw in row.get("name", "").lower():
                out[row["name"]] = row.get(code, "n/a")
                break
    return out


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: python -m app.scripts.discover_ifct_columns /path/to/cloned/ifct2017")
        sys.exit(1)

    repo = Path(sys.argv[1])
    columns_csv = repo / "columns" / "index.csv"
    reps_csv = repo / "representations" / "index.csv"
    comp_csv = repo / "compositions" / "index.csv"

    for p in (columns_csv, reps_csv, comp_csv):
        if not p.exists():
            print(f"Expected file not found: {p}\n"
                  f"Open the repo and check the actual folder/file layout — "
                  f"it may differ from what this script assumes.")
            sys.exit(1)

    columns = load_csv(columns_csv)
    reps = {r.get("code") or r.get("type"): r for r in load_csv(reps_csv)}  # key may differ — verify below
    compositions = load_csv(comp_csv)

    print(f"Loaded {len(columns)} columns, {len(reps)} representations, {len(compositions)} foods.\n")
    if columns:
        print(f"columns/index.csv headers found: {list(columns[0].keys())}")
    if reps:
        print(f"representations/index.csv headers found: {list(next(iter(reps.values())).keys())}")
    print("(If these don't look like {code, name, tags} / {code, type, factor, unit} — the")
    print(" join logic below is wrong for this repo layout; fix key_field/name_field/tags_field.)\n")

    mapping_template: dict = {}

    for target, keywords in SEARCH_TERMS.items():
        candidates = find_column(columns, "code", "name", "tags", keywords)
        print(f"=== {target} ===  (searched for: {keywords})")
        if not candidates:
            print("  No candidates found — check compositions/index.csv manually for this nutrient.")
            mapping_template[target] = {"code": None, "factor_to_target_unit": None, "note": "NOT FOUND — check manually"}
            print()
            continue

        for c in candidates:
            code = c.get("code")
            rep = reps.get(code, {})
            samples = sample_values(compositions, code) if code else {}
            print(f"  code={code!r}  name={c.get('name')!r}  unit={rep.get('unit', '?')}  factor={rep.get('factor', '?')}")
            for food_name, val in samples.items():
                print(f"      {food_name}: raw value = {val}")

        mapping_template[target] = {
            "code": candidates[0].get("code") if len(candidates) == 1 else "CHOOSE_FROM_ABOVE",
            "factor_to_target_unit": "VERIFY_AGAINST_SAMPLES_ABOVE",
            "candidates_seen": [c.get("code") for c in candidates],
        }
        print()

    out_path = Path("ifct_column_mapping.template.json")
    out_path.write_text(json.dumps(mapping_template, indent=2), encoding="utf-8")
    print(f"Wrote {out_path} — fill in 'code' and 'factor_to_target_unit' for every entry,")
    print("rename to ifct_column_mapping.json, then run convert_ifct_to_template.py.")
    print()
    print("Note: omega3_ala / omega3_epa / omega3_dha are three separate entries because")
    print("omega3_g in our schema is their SUM — convert_ifct_to_template.py adds them.")


if __name__ == "__main__":
    main()
