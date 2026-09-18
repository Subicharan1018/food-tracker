"""Validated contract between the recipe extraction model and the calculator."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ExtractedIngredient(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, description="Ingredient name without the quantity")
    amount: float | None = Field(default=None, ge=0)
    unit: str | None = None
    grams: float | None = Field(default=None, ge=0)
    state: Literal["raw", "dry", "cooked", "unclear"] = "unclear"
    confidence: float = Field(default=0.0, ge=0, le=1)


class RecipeExtraction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1)
    meal_slot: Literal["breakfast", "lunch", "dinner", "snack"]
    method: str = ""
    ingredients: list[ExtractedIngredient] = Field(min_length=1)
