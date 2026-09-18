# Recipe import contract

Recipes copied from ChatGPT should use this format:

```text
RECIPE: Chicken Biryani
SERVINGS: 4

INGREDIENTS:
- chicken | 500 | g | raw
- seeraga samba rice | 250 | g | dry
- onion | 150 | g | raw
- tomato | 150 | g | raw
- curd | 100 | g | raw
- oil | 25 | ml | raw
- ghee | 5 | g | raw

METHOD:
...
```

The backend parses this contract locally and does not spend a Nemotron request. It resolves each ingredient against the IFCT database (with a small disclosed curated fallback for common missing items), calculates macros and kcal deterministically, and returns both:

- `total_calories`: the complete recipe
- `calories`: kcal per serving

Nemotron is only used as a forced extraction-tool fallback when pasted text is not in this format. It extracts names, quantities, units, and raw/cooked state; it is never allowed to invent nutrition values.

If an ingredient cannot be matched, the response includes a warning and excludes that ingredient from the numeric total. Treat that result as needing correction rather than as an exact kcal value.
