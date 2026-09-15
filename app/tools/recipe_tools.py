async def search_recipes(
    recipes: list[dict],
    meal_slot: str,
    max_cal: int = 9999,
    min_protein: int = 0,
) -> list[dict]:
    results = [
        r for r in recipes
        if r.get("mealSlot") == meal_slot
        and float(r.get("calories", 9999)) <= max_cal
        and float(r.get("proteinG", 0)) >= min_protein
    ]
    return sorted(results, key=lambda r: float(r.get("proteinG", 0)), reverse=True)[:5]

async def get_gap_filler_snacks(
    recipes: list[dict],
    remaining_cal: int,
    remaining_protein: int,
) -> list[dict]:
    snacks = [r for r in recipes if r.get("mealSlot") == "snack"]

    def score(r: dict) -> float:
        cal_diff  = abs(float(r.get("calories", 0)) - remaining_cal)
        prot_diff = abs(float(r.get("proteinG", 0)) - remaining_protein)
        return cal_diff + prot_diff * 2.0

    return sorted(snacks, key=score)[:3]

async def get_recipe_detail(recipes: list[dict], recipe_name: str) -> dict:
    for r in recipes:
        if r.get("name", "").lower() == recipe_name.lower():
            return r
    return {}
