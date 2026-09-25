"""Shopping Cart & Shopping List API.

Endpoints:
  GET  /shopping-list/{user_id}              — latest generated shopping list
  POST /shopping-list/generate               — run ceiling + structural-gaps now
  GET  /cart/{user_id}                       — all active cart items
  POST /cart/{user_id}/add                   — add/deduplicate one item
  PATCH /cart/{user_id}/item/{item_id}       — toggle checked, update qty
  DELETE /cart/{user_id}/item/{item_id}      — delete one item
  POST /cart/{user_id}/checkout              — clear checked items, return count
"""
from __future__ import annotations

import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.dependencies import get_firestore_service
from app.services.firestore_service import FirestoreService
from app.services.nutrient_calculator import _normalise, load_nutrient_profiles
from app.services.nutrient_coverage_service import (
    compute_structural_gaps_detail,
    compute_weekly_nutrient_ceiling,
)

router = APIRouter()


# ── Request models ─────────────────────────────────────────────────────────

class GenerateShoppingListRequest(BaseModel):
    user_id: str = Field(min_length=1)


class AddToCartRequest(BaseModel):
    name: str = Field(min_length=1)
    canonical_name: str = Field(min_length=1)
    quantity: float = Field(default=1.0, gt=0)
    unit: str = Field(default="pieces")
    added_from: str = Field(
        description="shopping_list | nutrient_gap | recipe_suggestion | manual"
    )
    reason: str | None = Field(default=None)


class UpdateCartItemRequest(BaseModel):
    checked: bool | None = None
    quantity: float | None = Field(default=None, gt=0)
    unit: str | None = None


# ── Shopping List ─────────────────────────────────────────────────────────

@router.get("/shopping-list/{user_id}")
async def get_shopping_list(
    user_id: str,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Return the most recently generated shopping list for a user."""
    from datetime import date
    week = f"{date.today().isocalendar().year}-W{date.today().isocalendar().week:02d}"
    result = firestore.get_shopping_list(user_id, week)
    if not result:
        return {"shopping_list": None, "week": week, "message": "No shopping list generated yet for this week."}
    return result


@router.post("/shopping-list/generate")
async def generate_shopping_list(
    request: GenerateShoppingListRequest,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Generate and persist the weekly nutrient ceiling + structural gaps detail.

    This is the Saturday scheduled job entry point — also callable on demand.
    """
    from datetime import date
    user_id = request.user_id
    inventory = firestore.get_inventory(user_id)
    recipes = firestore.get_recipes(user_id)

    try:
        nutrient_db = load_nutrient_profiles()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Could not load nutrient profiles: {e}")

    ceiling = compute_weekly_nutrient_ceiling(inventory, nutrient_db)
    gaps_detail = compute_structural_gaps_detail(
        ceiling.get("structural_gaps", []),
        recipes,
        inventory,
        nutrient_db,
    )

    from datetime import date as _date
    week = f"{_date.today().isocalendar().year}-W{_date.today().isocalendar().week:02d}"

    payload = {
        **ceiling,
        "structural_gaps_detail": gaps_detail,
        "week": week,
        "user_id": user_id,
    }
    firestore.save_shopping_list(user_id, week, payload)
    return payload


# ── Cart ─────────────────────────────────────────────────────────────────────

@router.get("/cart/{user_id}")
async def get_cart(
    user_id: str,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Return all active cart items for a user (unchecked + checked)."""
    items = firestore.get_cart_items(user_id)
    return {"items": items, "count": len(items)}


@router.post("/cart/{user_id}/add")
async def add_to_cart(
    user_id: str,
    body: AddToCartRequest,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Add an item to the cart, deduplicating by canonical_name.

    If an unchecked item with the same canonical_name already exists, the
    existing item is returned unchanged — no duplicate is created.

    If a checked (purchased) item with the same canonical_name exists, a new
    unchecked item is created so the user can buy it again.
    """
    canonical = _normalise(body.canonical_name)

    # Deduplication check
    existing_items = firestore.get_cart_items(user_id)
    for item in existing_items:
        if (
            _normalise(str(item.get("canonicalName") or item.get("canonical_name") or "")) == canonical
            and not item.get("checked", False)
        ):
            return {
                "action": "existing",
                "item": item,
                "message": f"'{canonical}' is already in your cart (unchecked).",
            }

    # New item
    import uuid
    item_id = str(uuid.uuid4())
    now = datetime.now(timezone.utc).isoformat()
    item = {
        "name": body.name,
        "canonicalName": canonical,
        "quantity": body.quantity,
        "unit": body.unit,
        "addedFrom": body.added_from,
        "reason": body.reason,
        "checked": False,
        "addedAt": now,
        "updatedAt": now,
        "isDirty": True,
    }
    firestore.upsert_cart_item(user_id, item_id, item)
    return {"action": "added", "item": {**item, "id": item_id}}


@router.patch("/cart/{user_id}/item/{item_id}")
async def update_cart_item(
    user_id: str,
    item_id: str,
    body: UpdateCartItemRequest,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Toggle checked state or update quantity/unit for a cart item."""
    items = firestore.get_cart_items(user_id)
    existing = next((i for i in items if i.get("id") == item_id), None)
    if not existing:
        raise HTTPException(status_code=404, detail="Cart item not found.")

    updated = {**existing}
    if body.checked is not None:
        updated["checked"] = body.checked
    if body.quantity is not None:
        updated["quantity"] = body.quantity
    if body.unit is not None:
        updated["unit"] = body.unit
    updated["updatedAt"] = datetime.now(timezone.utc).isoformat()
    updated["isDirty"] = True

    firestore.upsert_cart_item(user_id, item_id, updated)
    return {"action": "updated", "item": updated}


@router.delete("/cart/{user_id}/item/{item_id}")
async def delete_cart_item(
    user_id: str,
    item_id: str,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Remove a specific item from the cart (swipe-to-delete)."""
    ok = firestore.delete_cart_item(user_id, item_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Cart item not found or Firestore unavailable.")
    return {"action": "deleted", "item_id": item_id}


@router.post("/cart/{user_id}/checkout")
async def checkout_cart(
    user_id: str,
    firestore: FirestoreService = Depends(get_firestore_service),
):
    """Clear all checked items and return a summary.

    The Flutter client handles the inventory increment/create step locally
    (via the checkout sheet), then syncs to Firestore via the existing sync
    service.  This endpoint handles the server-side cart cleanup so the next
    backend job (shopping-list generation, pacing check) sees an accurate cart.
    """
    cleared = firestore.delete_checked_cart_items(user_id)
    return {
        "action": "checkout_complete",
        "items_cleared": cleared,
        "cleared_at": datetime.now(timezone.utc).isoformat(),
    }
