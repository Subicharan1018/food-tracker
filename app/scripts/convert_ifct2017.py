#!/usr/bin/env python3
"""
IFCT 2017 (Indian Food Composition Tables) Database Converter
Converts IFCT 2017 raw data from CSVs into:
1. SQLite Database (`app/data/ifct2017.db`) with full normalized schema + FTS5 search
2. JSON Database (`ifct2017_foods.json`)
3. Drift/Dart Seed File (`lib/core/local_db/ifct2017_seed_data.dart`) for Kinetik Food Tracker
"""

import os
import re
import csv
import json
import sqlite3
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
IFCT_DIR = BASE_DIR / "ifct2017"
OUTPUT_DB = BASE_DIR / "app" / "data" / "ifct2017.db"
OUTPUT_JSON = BASE_DIR / "ifct2017_foods.json"
OUTPUT_DART = BASE_DIR / "lib" / "core" / "local_db" / "ifct2017_seed_data.dart"

def parse_regional_names(desc_str: str) -> dict:
    """Parses local language names from IFCT description string."""
    names = {
        "tamil": None,
        "hindi": None,
        "telugu": None,
        "malayalam": None,
        "kannada": None,
        "bengali": None,
        "gujarati": None,
        "marathi": None,
        "oriya": None,
        "punjabi": None,
        "assamese": None,
        "kashmiri": None,
        "urdu": None,
    }
    if not desc_str:
        return names

    lang_map = {
        r'(?:Tam\.|Tamil)\s*([^;]+)': 'tamil',
        r'(?:H\.|Hindi)\s*([^;]+)': 'hindi',
        r'(?:Tel\.|Telugu)\s*([^;]+)': 'telugu',
        r'(?:Mal\.|Malayalam)\s*([^;]+)': 'malayalam',
        r'(?:Kan\.|Kannada)\s*([^;]+)': 'kannada',
        r'(?:B\.|Ben\.|Bengali)\s*([^;]+)': 'bengali',
        r'(?:G\.|Guj\.|Gujarati)\s*([^;]+)': 'gujarati',
        r'(?:Mar\.|Marathi)\s*([^;]+)': 'marathi',
        r'(?:O\.|Oriya|Odia)\s*([^;]+)': 'oriya',
        r'(?:P\.|Punjabi)\s*([^;]+)': 'punjabi',
        r'(?:A\.|Assamese)\s*([^;]+)': 'assamese',
        r'(?:Kash\.|Kashmiri)\s*([^;]+)': 'kashmiri',
        r'(?:U\.|Urdu)\s*([^;]+)': 'urdu',
    }

    for pattern, key in lang_map.items():
        m = re.search(pattern, desc_str, re.IGNORECASE)
        if m:
            val = m.group(1).strip().rstrip('.,;')
            names[key] = val

    return names

def to_float(val, default=0.0):
    if val is None or val == "":
        return default
    try:
        f = float(val)
        return 0.0 if (f != f) else f
    except (ValueError, TypeError):
        return default

def convert():
    print("Starting IFCT 2017 Conversion...")
    OUTPUT_DB.parent.mkdir(parents=True, exist_ok=True)

    if not IFCT_DIR.exists():
        print(f"IFCT directory not found at {IFCT_DIR}. Skipping raw build.")
        return

    # 1. Load Descriptions
    descriptions = {}
    with open(IFCT_DIR / "descriptions" / "index.csv", "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            code = row.get("code")
            if code:
                descriptions[code] = row

    # 2. Load Groups
    groups = {}
    with open(IFCT_DIR / "groups" / "index.csv", "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        for row in reader:
            code = row.get("code")
            if code:
                groups[code] = row

    # 3. Load Column Descriptions & Representations
    col_meta = {}
    if (IFCT_DIR / "columndescriptions" / "index.csv").exists():
        with open(IFCT_DIR / "columndescriptions" / "index.csv", "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            for row in reader:
                col_meta[row.get("code")] = row

    representations = {}
    if (IFCT_DIR / "representations" / "index.csv").exists():
        with open(IFCT_DIR / "representations" / "index.csv", "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.DictReader(f)
            for row in reader:
                representations[row.get("code")] = row

    # 4. Load Compositions Raw
    compositions_raw = []
    with open(IFCT_DIR / "compositions" / "index.csv", "r", encoding="utf-8", errors="ignore") as f:
        reader = csv.DictReader(f)
        compositions_raw = list(reader)

    print(f"Loaded {len(compositions_raw)} food compositions.")

    foods = []
    for row in compositions_raw:
        code = row.get("code", "")
        desc_info = descriptions.get(code, {})
        local_names_raw = desc_info.get("desc", row.get("lang", ""))
        regional = parse_regional_names(local_names_raw)

        enerc_kj = to_float(row.get("enerc"))
        enerc_kcal = round(enerc_kj / 4.184, 1)

        food = {
            "code": code,
            "name": row.get("name", desc_info.get("name", "")),
            "scientific_name": row.get("scie", desc_info.get("scie", "")),
            "food_group": row.get("grup", desc_info.get("grup", "")),
            "group_code": code[0] if code else "",
            "local_names": local_names_raw,
            "tamil_name": regional["tamil"],
            "hindi_name": regional["hindi"],
            "telugu_name": regional["telugu"],
            "malayalam_name": regional["malayalam"],
            "kannada_name": regional["kannada"],
            "bengali_name": regional["bengali"],
            "gujarati_name": regional["gujarati"],
            "marathi_name": regional["marathi"],
            "dietary_tags": row.get("tags", ""),
            "serving_size": 100.0,
            "serving_unit": "g",
            "energy_kj": enerc_kj,
            "energy_kcal": enerc_kcal,
            "protein_g": round(to_float(row.get("protcnt")), 2),
            "carbohydrates_g": round(to_float(row.get("choavldf")), 2),
            "fat_g": round(to_float(row.get("fatce")), 2),
            "fiber_g": round(to_float(row.get("fibtg")), 2),
            "water_g": round(to_float(row.get("water")), 2),
            "ash_g": round(to_float(row.get("ash")), 2),
            "calcium_mg": round(to_float(row.get("ca")) * 1000, 2),
            "iron_mg": round(to_float(row.get("fe")) * 1000, 2),
            "magnesium_mg": round(to_float(row.get("mg")) * 1000, 2),
            "phosphorus_mg": round(to_float(row.get("p")) * 1000, 2),
            "potassium_mg": round(to_float(row.get("k")) * 1000, 2),
            "sodium_mg": round(to_float(row.get("na")) * 1000, 2),
            "zinc_mg": round(to_float(row.get("zn")) * 1000, 2),
            "copper_mg": round(to_float(row.get("cu")) * 1000, 2),
            "manganese_mg": round(to_float(row.get("mn")) * 1000, 2),
            "selenium_ug": round(to_float(row.get("se")) * 1000000, 2),
            "vitamin_a_ug": round(to_float(row.get("vita")) * 1000000, 2),
            "vitamin_c_mg": round(to_float(row.get("vitc")) * 1000, 2),
            "thiamine_b1_mg": round(to_float(row.get("thia")) * 1000, 2),
            "riboflavin_b2_mg": round(to_float(row.get("ribf")) * 1000, 2),
            "niacin_b3_mg": round(to_float(row.get("nia")) * 1000, 2),
            "vitamin_b6_mg": round(to_float(row.get("vitb6c")) * 1000, 2),
            "folate_b9_ug": round(to_float(row.get("folsum")) * 1000000, 2),
            "vitamin_e_mg": round(to_float(row.get("vite")) * 1000, 2),
            "vitamin_d_ug": round(to_float(row.get("vitd")) * 1000000, 2),
            "vitamin_k_ug": round(to_float(row.get("vitk")) * 1000000, 2),
            "histidine_g": round(to_float(row.get("his")), 3),
            "isoleucine_g": round(to_float(row.get("ile")), 3),
            "leucine_g": round(to_float(row.get("leu")), 3),
            "lysine_g": round(to_float(row.get("lys")), 3),
            "methionine_g": round(to_float(row.get("met")), 3),
            "phenylalanine_g": round(to_float(row.get("phe")), 3),
            "threonine_g": round(to_float(row.get("thr")), 3),
            "tryptophan_g": round(to_float(row.get("trp")), 3),
            "valine_g": round(to_float(row.get("val")), 3),
            "saturated_fat_g": round(to_float(row.get("fasat")), 2),
            "monounsaturated_fat_g": round(to_float(row.get("fams")), 2),
            "polyunsaturated_fat_g": round(to_float(row.get("fapu")), 2),
            "cholesterol_mg": round(to_float(row.get("cholc")) * 1000, 2),
        }
        foods.append(food)

    if OUTPUT_DB.exists():
        OUTPUT_DB.unlink()

    conn = sqlite3.connect(OUTPUT_DB)
    cur = conn.cursor()

    cur.execute("""
    CREATE TABLE foods (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        scientific_name TEXT,
        food_group TEXT NOT NULL,
        group_code TEXT,
        local_names TEXT,
        tamil_name TEXT,
        hindi_name TEXT,
        telugu_name TEXT,
        malayalam_name TEXT,
        kannada_name TEXT,
        bengali_name TEXT,
        gujarati_name TEXT,
        marathi_name TEXT,
        dietary_tags TEXT,
        serving_size REAL DEFAULT 100.0,
        serving_unit TEXT DEFAULT 'g',
        energy_kj REAL,
        energy_kcal REAL,
        protein_g REAL,
        carbohydrates_g REAL,
        fat_g REAL,
        fiber_g REAL,
        water_g REAL,
        ash_g REAL,
        calcium_mg REAL,
        iron_mg REAL,
        magnesium_mg REAL,
        phosphorus_mg REAL,
        potassium_mg REAL,
        sodium_mg REAL,
        zinc_mg REAL,
        copper_mg REAL,
        manganese_mg REAL,
        selenium_ug REAL,
        vitamin_a_ug REAL,
        vitamin_c_mg REAL,
        thiamine_b1_mg REAL,
        riboflavin_b2_mg REAL,
        niacin_b3_mg REAL,
        vitamin_b6_mg REAL,
        folate_b9_ug REAL,
        vitamin_e_mg REAL,
        vitamin_d_ug REAL,
        vitamin_k_ug REAL,
        histidine_g REAL,
        isoleucine_g REAL,
        leucine_g REAL,
        lysine_g REAL,
        methionine_g REAL,
        phenylalanine_g REAL,
        threonine_g REAL,
        tryptophan_g REAL,
        valine_g REAL,
        saturated_fat_g REAL,
        monounsaturated_fat_g REAL,
        polyunsaturated_fat_g REAL,
        cholesterol_mg REAL
    );
    """)

    food_cols = list(foods[0].keys())
    placeholders = ",".join(["?"] * len(food_cols))
    insert_sql = f"INSERT INTO foods ({','.join(food_cols)}) VALUES ({placeholders})"
    for f in foods:
        cur.execute(insert_sql, [f[col] for col in food_cols])

    cur.execute("""
    CREATE VIRTUAL TABLE foods_fts USING fts5(
        code UNINDEXED,
        name,
        scientific_name,
        food_group,
        local_names,
        tamil_name,
        hindi_name,
        telugu_name,
        malayalam_name,
        kannada_name,
        content=foods,
        content_rowid=rowid
    );
    """)
    cur.execute("""
    INSERT INTO foods_fts(rowid, code, name, scientific_name, food_group, local_names, tamil_name, hindi_name, telugu_name, malayalam_name, kannada_name)
    SELECT rowid, code, name, scientific_name, food_group, local_names, tamil_name, hindi_name, telugu_name, malayalam_name, kannada_name FROM foods;
    """)

    cur.execute("""
    CREATE TABLE food_groups (
        code TEXT PRIMARY KEY,
        group_name TEXT NOT NULL,
        entries_count INTEGER,
        tags TEXT
    );
    """)
    for code, g in groups.items():
        cur.execute("INSERT INTO food_groups VALUES (?, ?, ?, ?)", (
            code, g.get("group", ""), int(g.get("entries", 0) or 0), g.get("tags", "")
        ))

    cur.execute("""
    CREATE TABLE columns_meta (
        code TEXT PRIMARY KEY,
        name TEXT,
        short_desc TEXT,
        long_desc TEXT,
        data_type TEXT,
        factor REAL,
        unit TEXT
    );
    """)
    for code, cm in col_meta.items():
        rep = representations.get(code, {})
        cur.execute("INSERT INTO columns_meta VALUES (?, ?, ?, ?, ?, ?, ?)", (
            code,
            cm.get("name", ""),
            cm.get("shortdesc", ""),
            cm.get("longdesc", ""),
            rep.get("type", ""),
            to_float(rep.get("factor", 0)),
            rep.get("unit", "")
        ))

    if compositions_raw:
        raw_headers = list(compositions_raw[0].keys())
        col_defs = [f'"{col}" TEXT' for col in raw_headers]
        cur.execute(f"CREATE TABLE compositions_raw ({', '.join(col_defs)});")
        raw_placeholders = ",".join(["?"] * len(raw_headers))
        raw_insert_sql = f"INSERT INTO compositions_raw VALUES ({raw_placeholders})"
        for r in compositions_raw:
            cur.execute(raw_insert_sql, [r.get(col, "") for col in raw_headers])

    cur.execute("CREATE INDEX idx_foods_name ON foods(name);")
    cur.execute("CREATE INDEX idx_foods_group ON foods(food_group);")
    cur.execute("CREATE INDEX idx_foods_protein ON foods(protein_g DESC);")
    cur.execute("CREATE INDEX idx_foods_calories ON foods(energy_kcal ASC);")

    conn.commit()
    conn.close()
    print(f"✅ SQLite Database created successfully: {OUTPUT_DB}")

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(foods, f, indent=2, ensure_ascii=False)
    print(f"✅ JSON Database created successfully: {OUTPUT_JSON}")

    category_map = {
        "Cereals and Millets": "grain",
        "Grain Legumes": "protein",
        "Green Leafy Vegetables": "vegetable",
        "Other Vegetables": "vegetable",
        "Fruits": "fruit",
        "Roots and Tubers": "carb",
        "Condiments and Spices": "condiment",
        "Nuts and Oil Seeds": "fat",
        "Oil and Fats": "fat",
        "Sugars": "snack",
        "Milk and Milk Products": "dairy",
        "Egg, Meat and Poultry": "protein",
        "Fish and Other Sea Foods": "protein",
        "Miscellaneous Foods": "generic",
    }

    dart_lines = [
        "// AUTO-GENERATED IFCT 2017 INDIAN FOOD COMPOSITION SEED DATA",
        "// Source: National Institute of Nutrition (ICMR), Hyderabad",
        "// Total Foods: 542 items with macro & micro nutrient profiles",
        "",
        "import 'package:drift/drift.dart';",
        "import 'app_database.dart';",
        "",
        "class Ifct2017FoodSeed {",
        "  static const List<FoodItemsCompanion> allFoods = [",
    ]

    for f in foods:
        fid = f"ifct_{f['code'].lower()}"
        cat = category_map.get(f['food_group'], 'generic')
        name_esc = f['name'].replace("'", "\\'")
        if f['tamil_name']:
            t_name = f['tamil_name'].replace("'", "\\'")
            displayName = f"{name_esc} ({t_name})"
        elif f['hindi_name']:
            h_name = f['hindi_name'].replace("'", "\\'")
            displayName = f"{name_esc} ({h_name})"
        else:
            displayName = name_esc

        dart_lines.append("    FoodItemsCompanion(")
        dart_lines.append(f"      id: Value('{fid}'),")
        dart_lines.append(f"      name: Value('{displayName}'),")
        dart_lines.append("      brand: Value(null),")
        dart_lines.append(f"      category: Value('{cat}'),")
        dart_lines.append("      servingSize: Value(100.0),")
        dart_lines.append("      servingUnit: Value('g'),")
        dart_lines.append(f"      calories: Value({f['energy_kcal']}),")
        dart_lines.append(f"      proteinG: Value({f['protein_g']}),")
        dart_lines.append(f"      carbsG: Value({f['carbohydrates_g']}),")
        dart_lines.append(f"      fatG: Value({f['fat_g']}),")
        dart_lines.append(f"      fiberG: Value({f['fiber_g']}),")
        dart_lines.append("      source: Value('icmr_nin_2017'),")
        dart_lines.append("      isGeneric: Value(true),")
        dart_lines.append("    ),")

    dart_lines.extend([
        "  ];",
        "}",
        "",
    ])

    OUTPUT_DART.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_DART, "w", encoding="utf-8") as f:
        f.write("\n".join(dart_lines))
    print(f"✅ Dart Seed File created successfully: {OUTPUT_DART}")

if __name__ == "__main__":
    convert()
