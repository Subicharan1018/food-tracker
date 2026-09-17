"""Documented cooking-unit conversions used by nutrient calculations.

The nutrient reference values are all per 100 g.  Piece weights are kept
explicitly by ingredient because a generic "piece" conversion is not valid.
Unknown units deliberately return ``None`` in the calculator.
"""

UNIT_TO_GRAMS = {
    "g": 1.0,
    "gram": 1.0,
    "kg": 1000.0,
    "ml": 1.0,  # only used for water-density liquids; ingredient overrides win
    "l": 1000.0,
    "tsp": 5.0,
    "tbsp": 15.0,
    "cup": 240.0,
}

# Standard edible/cooked weights.  These are intentionally narrow: unknown
# foods remain uncomputed until reviewed rather than receiving a generic value.
PIECE_WEIGHTS_G = {
    "egg": 55.0,
    "whole egg": 55.0,
    "chapati": 40.0,
    "banana": 120.0,
    "onion": 110.0,
    "tomato": 100.0,
    "lemon": 45.0,
    "garlic": 3.0,
    "green chilli": 5.0,
    "green chili": 5.0,
}

# Ingredient-specific density/measurements take precedence over generic units.
INGREDIENT_UNIT_WEIGHTS_G = {
    ("cooking oil", "tsp"): 4.5,
    ("oil", "tsp"): 4.5,
    ("whey protein", "scoop"): 30.0,
    ("whey", "scoop"): 30.0,
    ("garlic", "clove"): 3.0,
    ("ginger", "inch"): 5.0,
}
