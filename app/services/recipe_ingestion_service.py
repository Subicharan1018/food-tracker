"""AI-assisted recipe parsing, IFCT matching, nutrition calculation, and storage."""

from __future__ import annotations

import hashlib
import html
import json
import re
from datetime import datetime, timezone
from typing import Any

from app.config import logger
from app.services.food_db_service import FoodDbService
from app.services.firestore_service import FirestoreService
from app.services.nemotron_service import NemotronService


_FRACTIONS = {
    "¼": 0.25,
    "½": 0.5,
    "¾": 0.75,
    "⅐": 1 / 7,
    "⅑": 1 / 9,
    "⅒": 0.1,
    "⅓": 1 / 3,
    "⅔": 2 / 3,
    "⅕": 0.2,
    "⅖": 0.4,
    "⅗": 0.6,
    "⅘": 0.8,
    "⅙": 1 / 6,
    "⅚": 5 / 6,
    "⅛": 0.125,
    "⅜": 0.375,
    "⅝": 0.625,
    "⅞": 0.875,
}

_UNITS = {
    "g": "g",
    "gram": "g",
    "grams": "g",
    "kg": "kg",
    "kilogram": "kg",
    "kilograms": "kg",
    "mg": "mg",
    "milligram": "mg",
    "milligrams": "mg",
    "ml": "ml",
    "millilitre": "ml",
    "millilitres": "ml",
    "milliliter": "ml",
    "milliliters": "ml",
    "l": "l",
    "litre": "l",
    "litres": "l",
    "liter": "l",
    "liters": "l",
    "tsp": "tsp",
    "teaspoon": "tsp",
    "teaspoons": "tsp",
    "tbsp": "tbsp",
    "tablespoon": "tbsp",
    "tablespoons": "tbsp",
    "cup": "cup",
    "cups": "cup",
    "piece": "piece",
    "pieces": "piece",
    "pc": "piece",
    "pcs": "piece",
    "clove": "clove",
    "cloves": "clove",
    "medium": "medium",
    "small": "small",
    "large": "large",
    "serving": "serving",
    "servings": "serving",
}

_ALIASES = {
    "palak": "spinach",
    "spinach leaves": "spinach",
    "green chilli": "chillies green",
    "green chili": "chillies green",
    "red chilli powder": "chillies red",
    "red chili powder": "chillies red",
    "red chilli": "chillies red",
    "red chili": "chillies red",
    "ginger garlic": "ginger",
    "lemon juice": "lemon juice",
}

_NUMBER_RE = re.compile(
    r"(?:\d+(?:\.\d+)?(?:\s+\d+\s*/\s*\d+)?|\d+\s*/\s*\d+|[¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])"
)


def _normalise(value: str) -> str:
    value = html.unescape(str(value or "")).lower().strip()
    value = value.replace("&", " and ")
    value = re.sub(r"[^\w\s]", " ", value, flags=re.UNICODE)
    return re.sub(r"\s+", " ", value).strip()


def _parse_number(value: str | float | int | None) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (float, int)):
        return float(value)
    raw = str(value).strip().replace("−", "-")
    if not raw:
        return None
    total = 0.0
    found = False
    for token in raw.split():
        if token in _FRACTIONS:
            total += _FRACTIONS[token]
            found = True
        elif "/" in token:
            try:
                numerator, denominator = token.split("/", 1)
                total += float(numerator) / float(denominator)
                found = True
            except (ValueError, ZeroDivisionError):
                return None
        else:
            try:
                total += float(token)
                found = True
            except ValueError:
                return None
    return total if found else None


def _canonical_unit(unit: str | None) -> str | None:
    if not unit:
        return None
    cleaned = _normalise(unit)
    if cleaned in ("to taste", "as needed", "as required"):
        return cleaned
    return _UNITS.get(cleaned, cleaned or None)


def _parse_quantity(text: str) -> tuple[float | None, str | None, str]:
    """Parse a quantity prefix and return amount, unit, remaining ingredient name."""

    cleaned = re.sub(r"\*\*|__", "", html.unescape(text)).strip(" -–—:")
    if re.match(r"^(to taste|as needed|as required)$", cleaned, re.I):
        return None, cleaned.lower(), ""

    number_match = _NUMBER_RE.match(cleaned)
    if not number_match:
        lowered = cleaned.lower()
        if lowered in {"small", "medium", "large"}:
            return 1.0, lowered, ""
        if lowered.startswith("small piece"):
            return 1.0, "piece", cleaned[len("small piece") :].strip()
        if lowered.startswith("a small piece"):
            return 1.0, "piece", cleaned[len("a small piece") :].strip()
        if lowered.startswith("a piece"):
            return 1.0, "piece", cleaned[len("a piece") :].strip()
        return None, None, cleaned

    first = number_match.group(0)
    amount = _parse_number(first)
    rest = cleaned[number_match.end() :].strip()

    range_match = re.match(r"^(?:-|–|—|to)\s*" + _NUMBER_RE.pattern, rest, re.I)
    if range_match and amount is not None:
        second_token = _NUMBER_RE.search(range_match.group(0))
        second = _parse_number(second_token.group(0)) if second_token else None
        if second is not None:
            amount = (amount + second) / 2.0
        rest = rest[range_match.end() :].strip()

    unit = None
    for candidate in (" ".join(rest.split()[:2]), rest.split()[0] if rest.split() else ""):
        canonical = _canonical_unit(candidate)
        if canonical:
            unit = canonical
            rest = rest[len(candidate) :].strip()
            break

    return amount, unit, rest.strip(" -–—:")


def _split_ingredient_line(line: str) -> tuple[str, float | None, str | None]:
    line = re.sub(r"^\s*(?:[-*•]|\d+[.)])\s*", "", line)
    line = re.sub(r"\*\*|__", "", html.unescape(line)).strip()

    separator = re.split(r"\s+[—–]\s+|\s+-\s+|\s*:\s*", line, maxsplit=1)
    if len(separator) == 2:
        left, right = separator
        amount, unit, _ = _parse_quantity(right)
        if _normalise(right) in {"to taste", "as needed", "as required"}:
            unit = _normalise(right)
            amount = None
        return left.strip(), amount, unit

    amount, unit, name = _parse_quantity(line)
    return (name or line).strip(), amount, unit


def _estimate_grams(name: str, amount: float | None, unit: str | None) -> float:
    if amount is None or amount <= 0:
        return 0.0
    unit = _canonical_unit(unit)
    normalized = _normalise(name)

    if unit == "g":
        return amount
    if unit == "kg":
        return amount * 1000.0
    if unit == "mg":
        return amount / 1000.0
    if unit == "ml":
        density = 0.92 if "oil" in normalized else 1.0
        return amount * density
    if unit == "l":
        density = 0.92 if "oil" in normalized else 1.0
        return amount * 1000.0 * density
    if unit == "tsp":
        return amount * (4.5 if "oil" in normalized else 5.0)
    if unit == "tbsp":
        return amount * (13.5 if "oil" in normalized else 15.0)
    if unit == "cup":
        return amount * (218.0 if "spinach" in normalized or "palak" in normalized else 240.0)
    if unit == "serving":
        return amount * 100.0
    if unit == "clove":
        return amount * (3.0 if "garlic" in normalized else 5.0)
    if unit in {"piece", "small", "medium", "large"}:
        if "onion" in normalized:
            size = {"small": 70.0, "medium": 110.0, "large": 150.0}.get(unit, 10.0)
        elif "tomato" in normalized:
            size = {"small": 70.0, "medium": 100.0, "large": 150.0}.get(unit, 10.0)
        elif "chilli" in normalized or "chili" in normalized:
            size = {"small": 3.0, "medium": 5.0, "large": 8.0}.get(unit, 5.0)
        elif "ginger" in normalized:
            size = 5.0
        elif "garlic" in normalized:
            size = 3.0
        elif "lemon" in normalized:
            size = 45.0
        else:
            size = 100.0 if unit == "piece" else 10.0
        return amount * size
    return amount


def _extract_json(raw: str) -> Any:
    cleaned = (raw or "").strip()
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", cleaned, flags=re.I).strip()
    for opener, closer in (("{", "}"), ("[", "]")):
        start, end = cleaned.find(opener), cleaned.rfind(closer)
        if start >= 0 and end > start:
            try:
                return json.loads(cleaned[start : end + 1])
            except json.JSONDecodeError:
                continue
    return None


class RecipeIngestionService:
    """Turns a recipe message into a Firestore recipe compatible with the app."""

    def __init__(self, food_db: FoodDbService, firestore: FirestoreService):
        self._food_db = food_db
        self._firestore = firestore

    def _fallback_parse(self, recipe_text: str, meal_slot: str) -> dict[str, Any]:
        text = html.unescape(recipe_text).replace("\r", "")
        lines = [line.strip() for line in text.split("\n") if line.strip()]
        if not lines:
            return {"name": "Untitled recipe", "meal_slot": meal_slot, "ingredients": [], "method": ""}

        title = re.sub(r"^#+\s*", "", lines[0]).strip(" -*–—:")
        if "—" in title:
            title = title.split("—", 1)[0].strip()
        if not title or title.lower() in {"ingredients", "recipe"}:
            title = "Untitled recipe"

        ingredients = []
        for line in lines[1:]:
            if line.lower().startswith(("method:", "directions:", "instructions:")):
                break
            if not (line.startswith(("-", "*", "•")) or "—" in line or "–" in line or " : " in line):
                continue
            name, amount, unit = _split_ingredient_line(line)
            if name and _normalise(name) not in {"ingredients", "method", "directions"}:
                ingredients.append({
                    "name": name,
                    "amount": amount,
                    "unit": unit,
                    "grams": _estimate_grams(name, amount, unit),
                })

        return {"name": title, "meal_slot": meal_slot, "ingredients": ingredients, "method": ""}

    def _normalise_ai_data(self, data: Any, recipe_text: str, meal_slot: str) -> dict[str, Any] | None:
        if isinstance(data, list):
            data = {"ingredients": data}
        if not isinstance(data, dict):
            return None
        fallback = self._fallback_parse(recipe_text, meal_slot)
        name = str(data.get("name") or data.get("recipe_name") or fallback["name"]).strip()
        ingredients = []
        for raw_item in data.get("ingredients") or data.get("items") or []:
            if not isinstance(raw_item, dict):
                continue
            ingredient = str(
                raw_item.get("ingredient")
                or raw_item.get("name")
                or raw_item.get("food_name")
                or ""
            ).strip()
            amount = _parse_number(raw_item.get("amount", raw_item.get("quantity", raw_item.get("portion_qty"))))
            unit = _canonical_unit(raw_item.get("unit") or raw_item.get("portion_unit"))
            grams = _parse_number(raw_item.get("grams", raw_item.get("amount_g")))
            if ingredient and (amount is None or unit is None) and ("—" in ingredient or "–" in ingredient):
                ingredient, parsed_amount, parsed_unit = _split_ingredient_line(ingredient)
                amount = amount if amount is not None else parsed_amount
                unit = unit or parsed_unit
            if not ingredient:
                continue
            grams = grams if grams is not None else _estimate_grams(ingredient, amount, unit)
            ingredients.append({"name": ingredient, "amount": amount, "unit": unit, "grams": grams})
        if not ingredients:
            return fallback
        return {
            "name": name,
            "meal_slot": data.get("meal_slot") or meal_slot,
            "ingredients": ingredients,
            "method": str(data.get("method") or data.get("directions") or "").strip(),
        }

    async def _parse_with_agent(
        self,
        recipe_text: str,
        meal_slot: str,
        nemotron: NemotronService,
    ) -> dict[str, Any]:
        fallback = self._fallback_parse(recipe_text, meal_slot)
        system = (
            "You are Kinetik's recipe-ingestion agent. Extract every ingredient exactly once "
            "from the user's recipe, preserve explicit quantities, and normalize each quantity "
            "to an estimated edible gram weight when possible. Return ONLY JSON, never markdown."
        )
        user = (
            f"Default meal slot: {meal_slot}\n"
            f"Recipe text:\n{recipe_text}\n\n"
            "Return this shape: {\"name\":\"...\",\"meal_slot\":\"breakfast|lunch|dinner|snack\","
            "\"method\":\"...\",\"ingredients\":[{\"name\":\"Paneer\",\"amount\":150,"
            "\"unit\":\"g\",\"grams\":150}]} . Use null grams only when an estimate is impossible."
        )
        try:
            raw = await nemotron.complete(system, user, max_tokens=2500)
            parsed = self._normalise_ai_data(_extract_json(raw), recipe_text, meal_slot)
            return parsed or fallback
        except Exception as exc:
            logger.warning("Recipe AI parsing failed; using deterministic parser: %s", exc)
            return fallback

    def _resolve_food(self, ingredient_name: str) -> dict | None:
        normalized = _normalise(ingredient_name)
        query = _ALIASES.get(normalized, ingredient_name)
        try:
            candidates = self._food_db.search_foods(query, limit=20) or []
        except Exception as exc:
            logger.warning("IFCT lookup failed for recipe ingredient '%s': %s", ingredient_name, exc)
            return None
        if not candidates:
            return None

        query_tokens = set(_normalise(query).split())

        def score(row: dict) -> tuple[int, int]:
            name = _normalise(row.get("name", ""))
            name_tokens = set(name.split())
            overlap = len(query_tokens & name_tokens)
            exact = 1000 if name == _normalise(query) else 0
            contains = 100 if query_tokens and query_tokens.issubset(name_tokens) else 0
            return exact + contains + overlap * 10, -len(name)

        return max(candidates, key=score)

    def _nutrition_for_ingredient(self, parsed: dict[str, Any]) -> dict[str, Any]:
        name = str(parsed["name"])
        grams = max(float(parsed.get("grams") or 0.0), 0.0)
        food = self._resolve_food(name)
        result = {
            "ingredient": name,
            "matched_food": food.get("name") if food else None,
            "food_code": food.get("code") if food else None,
            "amount": parsed.get("amount"),
            "unit": parsed.get("unit"),
            "grams": round(grams, 2),
            "calories": 0.0,
            "protein_g": 0.0,
            "carbs_g": 0.0,
            "fat_g": 0.0,
            "fiber_g": 0.0,
            "resolved": bool(food),
        }
        if not food:
            return result
        serving_size = float(food.get("serving_size") or 100.0)
        factor = grams / serving_size if serving_size > 0 else 0.0
        result.update(
            calories=round(float(food.get("energy_kcal") or 0.0) * factor, 2),
            protein_g=round(float(food.get("protein_g") or 0.0) * factor, 2),
            carbs_g=round(float(food.get("carbohydrates_g") or 0.0) * factor, 2),
            fat_g=round(float(food.get("fat_g") or 0.0) * factor, 2),
            fiber_g=round(float(food.get("fiber_g") or 0.0) * factor, 2),
        )
        return result

    async def ingest(
        self,
        user_id: str,
        recipe_text: str,
        meal_slot: str,
        servings: float,
        nemotron: NemotronService,
    ) -> dict[str, Any]:
        parsed = await self._parse_with_agent(recipe_text, meal_slot, nemotron)
        ingredients = [self._nutrition_for_ingredient(item) for item in parsed["ingredients"]]
        warnings = []
        for item in ingredients:
            if not item["resolved"] and item["grams"] > 0:
                warnings.append(f"No IFCT match for '{item['ingredient']}'; excluded from nutrition totals.")
        if not ingredients:
            warnings.append("No ingredients were detected; recipe was stored with zero nutrition.")

        total = {
            "calories": sum(item["calories"] for item in ingredients) / servings,
            "protein_g": sum(item["protein_g"] for item in ingredients) / servings,
            "carbs_g": sum(item["carbs_g"] for item in ingredients) / servings,
            "fat_g": sum(item["fat_g"] for item in ingredients) / servings,
            "fiber_g": sum(item["fiber_g"] for item in ingredients) / servings,
        }
        name = str(parsed.get("name") or "Untitled recipe").strip()[:180]
        normalized_fingerprint = json.dumps(
            {"name": name, "meal_slot": meal_slot, "ingredients": ingredients},
            sort_keys=True,
            ensure_ascii=False,
        )
        slug = re.sub(r"[^a-z0-9]+", "_", _normalise(name)).strip("_") or "recipe"
        recipe_id = f"{slug}_{hashlib.sha1(normalized_fingerprint.encode('utf-8')).hexdigest()[:10]}"
        updated_at = datetime.now(timezone.utc).isoformat()
        display_ingredients = []
        for item in ingredients:
            amount = item.get("amount")
            unit = item.get("unit")
            if amount is not None and unit:
                quantity = f"{amount:g} {unit}"
            elif item["grams"] > 0:
                quantity = f"{item['grams']:g} g"
            else:
                quantity = "to taste"
            display_ingredients.append(f"{item['ingredient']} — {quantity}")
        payload = {
            "id": recipe_id,
            "name": name,
            "mealSlot": meal_slot,
            "servings": servings,
            "calories": round(total["calories"], 2),
            "proteinG": round(total["protein_g"], 2),
            "carbsG": round(total["carbs_g"], 2),
            "fatG": round(total["fat_g"], 2),
            "fiberG": round(total["fiber_g"], 2),
            # Keep the existing mobile sync contract (a list of display strings),
            # while retaining the complete IFCT audit trail in a second field.
            "ingredientsJson": json.dumps(display_ingredients, ensure_ascii=False),
            "ingredientDetailsJson": json.dumps(ingredients, ensure_ascii=False),
            "method": str(parsed.get("method") or ""),
            "tags": f"user-created,{meal_slot}",
            "source": "ai_recipe_ingestion",
            "updatedAt": updated_at,
            "createdAt": updated_at,
        }
        stored = self._firestore.save_recipe(user_id, recipe_id, payload)
        return {
            "id": recipe_id,
            "name": name,
            "meal_slot": meal_slot,
            "servings": servings,
            **{key: round(value, 2) for key, value in total.items()},
            "method": str(parsed.get("method") or ""),
            "ingredients": ingredients,
            "warnings": warnings,
            "stored": stored,
        }
