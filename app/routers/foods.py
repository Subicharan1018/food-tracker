from fastapi import APIRouter, Depends, HTTPException, Query
from app.services.food_db_service import FoodDbService
from app.dependencies import get_food_db_service

router = APIRouter()

@router.get("/foods/search")
async def search_foods(
    q: str = Query(..., min_length=1, description="Food name search query (English or Indian regional name)"),
    limit: int = Query(20, ge=1, le=100),
    food_db: FoodDbService = Depends(get_food_db_service),
):
    """Search the IFCT 2017 Indian Food Composition Database with FTS5."""
    results = food_db.search_foods(q, limit=limit)
    return {"query": q, "count": len(results), "foods": results}

@router.get("/foods/{code}")
async def get_food_detail(
    code: str,
    food_db: FoodDbService = Depends(get_food_db_service),
):
    """Retrieve full macro & micronutrient profile for an IFCT food item."""
    food = food_db.get_food_by_code(code)
    if not food:
        raise HTTPException(status_code=404, detail=f"Food with code '{code}' not found in IFCT database")
    return food
