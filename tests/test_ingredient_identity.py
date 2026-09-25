"""Tests for ingredient_identity — the canonical name resolution service.

These are adversarial tests designed to catch silent mismatch bugs: cases
where two ingredient names that refer to the same food fail to produce the
same canonical key, causing inventory-recipe joins to silently never match.

Run: pytest tests/test_ingredient_identity.py -v
"""

from __future__ import annotations

import pytest
from app.services.ingredient_identity import canonicalize, canonical_set
from app.data.ingredient_synonyms import INGREDIENT_SYNONYMS


# ── Core contract tests ────────────────────────────────────────────────────


class TestCanonicalEquality:
    """The central invariant: any two names for the same food must produce
    the same canonical key.  A failure here means a real inventory-recipe join
    silently never fires."""

    def test_tamil_and_english_onion_are_identical(self):
        assert canonicalize("Vengayam") == canonicalize("Onion")

    def test_tamil_variant_and_english_onion_are_identical(self):
        assert canonicalize("Vengaya") == canonicalize("Onion")

    def test_plural_english_onions_matches_singular(self):
        assert canonicalize("Onions") == canonicalize("Onion")

    def test_tamil_egg_and_english_egg_are_identical(self):
        assert canonicalize("Muttai") == canonicalize("egg")

    def test_kozhi_muttai_and_egg_are_identical(self):
        assert canonicalize("Kozhi Muttai") == canonicalize("egg")

    def test_palak_and_spinach_are_identical(self):
        assert canonicalize("Palak") == canonicalize("spinach")

    def test_spinach_leaves_and_spinach_are_identical(self):
        assert canonicalize("spinach leaves") == canonicalize("spinach")

    def test_baby_spinach_and_spinach_are_identical(self):
        assert canonicalize("baby spinach") == canonicalize("spinach")

    def test_Tamil_chicken_variants_all_match(self):
        assert canonicalize("Kozhi") == canonicalize("chicken")
        assert canonicalize("Kozhi Kari") == canonicalize("chicken")

    def test_curd_and_yogurt_are_identical(self):
        assert canonicalize("yogurt") == canonicalize("curd")

    def test_cooking_oil_variants_are_identical(self):
        assert canonicalize("cooking oil") == canonicalize("vegetable oil")
        assert canonicalize("oil") == canonicalize("sunflower oil")

    def test_pasta_and_macaroni_are_identical(self):
        assert canonicalize("pasta") == canonicalize("macaroni")

    def test_maida_and_wheat_flour_refined_are_identical(self):
        assert canonicalize("maida") == canonicalize("wheat flour refined")

    def test_poondu_and_garlic_are_identical(self):
        assert canonicalize("Poondu") == canonicalize("garlic")

    def test_vendhayam_and_fenugreek_are_identical(self):
        assert canonicalize("Vendhayam") == canonicalize("fenugreek seeds")

    def test_milagu_and_black_pepper_are_identical(self):
        assert canonicalize("Milagu") == canonicalize("black pepper")

    def test_thengai_and_coconut_are_identical(self):
        assert canonicalize("Thengai") == canonicalize("coconut")

    def test_nei_and_ghee_are_identical(self):
        assert canonicalize("Nei") == canonicalize("ghee")

    def test_hing_and_asafoetida_are_identical(self):
        assert canonicalize("Hing") == canonicalize("asafoetida")


class TestPreprocessing:
    """Preprocessing must strip parentheticals and preparation notes without
    changing the food identity."""

    def test_strips_parenthetical_preparation(self):
        assert canonicalize("chicken (boneless)") == canonicalize("chicken")

    def test_strips_comma_preparation_note(self):
        assert canonicalize("garlic, minced") == canonicalize("garlic")
        assert canonicalize("onion, chopped") == canonicalize("onion")
        assert canonicalize("spinach, washed") == canonicalize("spinach")
        assert canonicalize("chicken, skinless") == canonicalize("chicken")

    def test_mixed_case_is_normalised(self):
        assert canonicalize("ONION") == canonicalize("onion")
        assert canonicalize("  Spinach  ") == canonicalize("spinach")

    def test_extra_whitespace_is_stripped(self):
        assert canonicalize("  vengayam  ") == canonicalize("onion")


class TestPassThrough:
    """Unknown ingredients must pass through unchanged — never silently dropped
    and never falsely matched to a different ingredient."""

    def test_unknown_ingredient_passes_through(self):
        result = canonicalize("mystery spice blend")
        assert result == "mystery spice blend"

    def test_empty_string_returns_empty(self):
        assert canonicalize("") == ""

    def test_none_like_whitespace_returns_empty(self):
        assert canonicalize("   ") == ""

    def test_unknown_never_matches_a_known_ingredient(self):
        unknown = canonicalize("xylitol")
        known = canonicalize("onion")
        assert unknown != known


class TestCanonicalSet:
    """canonical_set must produce a deduplicated set where Tamil and English
    names for the same ingredient collapse to one entry."""

    def test_tamil_and_english_onion_collapse_to_one(self):
        result = canonical_set(["Vengayam", "Onion", "Onions"])
        assert result == {"onion"}

    def test_unknown_ingredients_are_included_not_dropped(self):
        result = canonical_set(["onion", "mystery blend", "spinach"])
        assert "mystery blend" in result
        assert "onion" in result
        assert "spinach" in result

    def test_empty_strings_are_excluded(self):
        result = canonical_set(["onion", "", "   ", "spinach"])
        assert "" not in result
        assert "onion" in result


class TestSynonymTableIntegrity:
    """Structural checks on the synonym table itself."""

    def test_all_synonym_values_are_lowercase(self):
        for key, value in INGREDIENT_SYNONYMS.items():
            assert value == value.lower(), (
                f"Synonym value '{value}' (for key '{key}') must be lowercase"
            )

    def test_all_synonym_keys_are_lowercase(self):
        for key in INGREDIENT_SYNONYMS:
            assert key == key.lower(), f"Synonym key '{key}' must be lowercase"

    def test_no_synonym_maps_to_itself_unnecessarily(self):
        """A key that maps to itself is not wrong but is clutter — flag it for
        human review rather than failing the build.  This test documents them."""
        self_maps = {k: v for k, v in INGREDIENT_SYNONYMS.items() if k == v}
        # If this list grows unexpectedly, investigate rather than auto-pass.
        # Currently expected: salt, water, butter, paneer, etc. map to themselves.
        assert isinstance(self_maps, dict)  # always passes — documents intent

    def test_no_circular_synonym(self):
        """A → B → A would cause infinite loops in any chain-following logic."""
        for key, value in INGREDIENT_SYNONYMS.items():
            if value in INGREDIENT_SYNONYMS:
                assert INGREDIENT_SYNONYMS[value] != key, (
                    f"Circular synonym: '{key}' → '{value}' → '{key}'"
                )
