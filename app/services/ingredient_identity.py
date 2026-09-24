"""Single source of truth for canonical ingredient name resolution.

Every place in the backend that compares ingredient names — recipe parsing,
inventory lookups, nutrient database queries — must call canonicalize() rather
than comparing raw display strings.  This ensures "Vengayam" from a Tamil
recipe and "Onions" from an English inventory entry resolve to the same key
("onion") and are correctly matched.

Usage:
    from app.services.ingredient_identity import canonicalize

    canonical = canonicalize("Vengayam")   # → "onion"
    canonical = canonicalize("Onions")     # → "onion"
    canonical = canonicalize("mystery")    # → "mystery" (pass-through, never dropped)
"""

from __future__ import annotations

import re
from app.data.ingredient_synonyms import INGREDIENT_SYNONYMS

# Parenthetical preparation descriptors that are not part of the food identity.
# Examples: "chicken (boneless)", "spinach (washed)", "rice (raw, washed)"
_PAREN_STRIP = re.compile(r"\s*\([^)]*\)")

# Trailing preparation descriptors after a comma that do not change what the
# food item *is*.  "garlic, minced" → "garlic".
_COMMA_STRIP = re.compile(r"\s*,\s*(minced|chopped|sliced|diced|grated|crushed|"
                          r"raw|cooked|dry|dried|washed|peeled|frozen|canned|"
                          r"boiled|roasted|ground|powdered|fresh|whole|halved|"
                          r"deseeded|deveined|skinless|boneless|cubed|julienned).*$",
                          re.IGNORECASE)


def _preprocess(raw: str) -> str:
    """Lowercase, strip parentheticals, strip trailing preparation notes."""
    name = raw.strip().lower()
    name = _PAREN_STRIP.sub("", name)
    name = _COMMA_STRIP.sub("", name)
    return name.strip()


def _depluralize(name: str) -> str:
    """Very light singular conversion — only for common English plurals.

    We do not want to blindly rstrip "s" because "eggs" → "egg" but
    "spinach" must not become "spinac".  The synonym table handles all
    regional and edge cases; this function only catches trivial English
    plurals that the synonym table omits to avoid bloat.
    """
    # "-ies" → "-y": tomatoes→tomato handled by synonym table.
    # Nothing fancy — keep it narrow and safe.
    if name.endswith("ies") and len(name) > 4:
        return name[:-3] + "y"
    return name


def canonicalize(raw_name: str) -> str:
    """Return the canonical ingredient key for any raw ingredient string.

    Steps:
      1. Pre-process: lowercase, strip preparation parentheticals & comma notes.
      2. Exact lookup in synonym table.
      3. Light depluralization, then retry synonym lookup.
      4. Pass-through: if still unmatched, return the preprocessed name.
         Unknown ingredients are never silently dropped; they simply carry
         through with whatever name they came in with so callers can report them.

    Args:
        raw_name: Any ingredient name string — Tamil, Hindi, English, with
                  preparation descriptors, plural, mixed-case, etc.

    Returns:
        A canonical lowercase English ingredient key suitable for use as a
        nutrient database key, inventory join key, or recipe cross-reference.
    """
    if not raw_name or not raw_name.strip():
        return ""

    preprocessed = _preprocess(raw_name)

    # 1. Direct synonym lookup
    if preprocessed in INGREDIENT_SYNONYMS:
        return INGREDIENT_SYNONYMS[preprocessed]

    # 2. After light depluralization
    singular = _depluralize(preprocessed)
    if singular in INGREDIENT_SYNONYMS:
        return INGREDIENT_SYNONYMS[singular]

    # 3. Pass-through — caller must handle unknown ingredients explicitly.
    return preprocessed


def canonical_set(names: list[str]) -> set[str]:
    """Canonicalize a list of ingredient names into a set of canonical keys."""
    return {canonicalize(name) for name in names if name and name.strip()}
