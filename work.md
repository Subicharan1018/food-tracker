# KINETIK — Implementation Progress
> Last updated: 2026-09-25 · Workspace: `c:\Users\yoges\Documents\food-tracker`

---

## ✅ DONE (this session)

### Backend — Part A: Two-Tier Nutrient Sourcing

| File | Status | Notes |
|------|--------|-------|
| `app/config.py` | ✅ Done | Added `usda_fdc_api_key: str = "DEMO_KEY"` field |
| `.env.example` | ✅ Done | Added `USDA_FDC_API_KEY=DEMO_KEY` with signup docs |
| `app/services/usda_fdc_client.py` | ✅ Done | Full async HTTPX client; omega-3 summed from 3 IDs (1404+1278+1272); absent nutrients stay absent (never set to 0); graceful HTTP error handling |
| `app/scripts/enrich_recipe_nutrients.py` | ✅ Done | Two-tier enrichment script: IFCT first → USDA fallback; `--ingredient NAME` flag; `--dry-run` flag; **human confirmation enforced at every step** |
| `tests/test_usda_fdc_client.py` | ✅ Done | 8 mocked tests: omega-3 summing, absent-nutrient exclusion, unknown-ID filtering, HTTP 404/403 degradation, null-amount exclusion |
| `requirements.txt` | ✅ Done | Added `respx==0.21.1` for HTTPX mocking in tests |

### Backend — Part B/C: Coverage Service + Structural Gaps

| File | Status | Notes |
|------|--------|-------|
| `app/services/nutrient_coverage_service.py` | ✅ Done | Added `compute_structural_gaps_detail()` — produces per-gap `{nutrient, unlocks_recipe, recipe_id, per_serving_amount, missing_ingredients}` objects; 20% daily RDA threshold; feeds Shopping Cart |

### Backend — Part D: Shopping Cart + Shopping List API

| File | Status | Notes |
|------|--------|-------|
| `app/services/firestore_service.py` | ✅ Done | Added `get_cart_items`, `upsert_cart_item`, `delete_checked_cart_items`, `delete_cart_item`, `save_shopping_list`, `get_shopping_list` |
| `app/routers/shopping.py` | ✅ Done | Full router: `GET/POST /api/shopping-list/`, `GET /api/cart/`, `POST /api/cart/{uid}/add` (dedup by canonical_name), `PATCH` toggle checked, `DELETE` item, `POST /checkout` (clears checked only) |
| `main.py` | ✅ Done | Registered `shopping.router` under `/api` prefix |
| `app/services/scheduler.py` | ✅ Done | Added Saturday 8 AM `_job_weekly_shopping_list` cron job |

---

## ❌ STILL TODO

### Backend — Tests (need venv on the server, not runnable from IDE)

| Task | Command on server |
|------|-------------------|
| Install respx | `pip install respx==0.21.1` |
| Run new USDA tests | `pytest tests/test_usda_fdc_client.py -v` |
| Full backend regression | `pytest tests/ -v` |
| Fix any import errors surfaced by tests | — |

### Backend — Stage 0 Sweep (needs Firestore creds on server)

```bash
# Run on the server after `pip install -r requirements.txt`
python -c "
import json
from app.services.firestore_service import firestore_service
from app.services.nutrient_calculator import compute_recipe_nutrients, load_nutrient_profiles
nutrient_db = load_nutrient_profiles()
recipes = firestore_service.get_recipes('<real_uid>')
gaps = [(r.get('name'), compute_recipe_nutrients(r, nutrient_db).get('missing_data', []))
        for r in recipes]
gaps = [(n, m) for n, m in gaps if m]
print(f'{len(gaps)} recipes with unresolved ingredients:')
for n, m in gaps: print(f'  {n}: {m}')
"
```

Then for each unresolved ingredient:
```bash
python -m app.scripts.enrich_recipe_nutrients --ingredient "oats"
# Human selects correct IFCT or USDA match, confirms write
```

---

## ❌ Flutter Frontend — NOT STARTED (entire Part D frontend)

### D.1 — Database Schema

**File:** `lib/core/local_db/app_database.dart`

- [ ] Add `ShoppingCartItems` table (schema below)
- [ ] Add `InventoryItems` table if not present (check — may already exist under another name)
- [ ] Bump `schemaVersion` from `1` → `2` and add `MigrationStrategy`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`

```dart
class ShoppingCartItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get canonicalName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('pieces'))();
  TextColumn get addedFrom => text()();  // "shopping_list"|"nutrient_gap"|"recipe_suggestion"|"manual"
  TextColumn get reason => text().nullable()();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
}
```

### D.2 — DB Helper Methods

**File:** `lib/core/local_db/app_database.dart` (add after existing helpers)

- [ ] `Future<ShoppingCartItem?> getCartItemByCanonicalName(String canonicalName)` — for dedup check
- [ ] `Future<List<ShoppingCartItem>> getAllCartItems()` — for screen
- [ ] `Stream<List<ShoppingCartItem>> watchCartItems()` — reactive list
- [ ] `Future<int> insertCartItem(ShoppingCartItemsCompanion item)`
- [ ] `Future<void> updateCartItem(int id, ShoppingCartItemsCompanion companion)`
- [ ] `Future<void> deleteCartItem(int id)`
- [ ] `Future<void> deleteCheckedCartItems()` — checkout clear
- [ ] `Future<List<ShoppingCartItem>> getDirtyCartItems()` — for sync push
- [ ] `Future<void> markCartItemsClean(List<int> ids)`
- [ ] Inventory helpers: `getInventoryItemByCanonicalName`, `incrementInventoryQuantity`, `createInventoryItem`

### D.3 — Shopping Cart Service

**Create:** `lib/features/shopping_cart/shopping_cart_service.dart`

- [ ] `addToCart({name, canonicalName, quantity, unit, addedFrom, reason})` — checks for existing unchecked row first; if found returns existing without inserting duplicate
- [ ] `toggleChecked(int id, bool checked)`
- [ ] `removeItem(int id)`
- [ ] `checkoutCart(List<ShoppingCartItem> checkedItems)` — for each item: increment or create InventoryItem by canonicalName, then delete checked cart items

### D.4 — Cart Screen

**Create:** `lib/features/shopping_cart/shopping_cart_screen.dart`

- [ ] Reactive `watchCartItems()` stream
- [ ] Unchecked items on top, checked items collapsed at bottom (crossed-out style)
- [ ] Each row: name, qty+unit, optional `reason` chip (e.g. "Unlocks Naatu Kozhi Kuzhambu")
- [ ] Tap → toggle checked/unchecked
- [ ] Swipe → delete
- [ ] "+" FAB → manual add dialog (`addedFrom: "manual"`)
- [ ] "Finish Shopping" button → opens `CartCheckoutSheet`

### D.5 — Checkout Sheet

**Create:** `lib/features/shopping_cart/cart_checkout_sheet.dart`

- [ ] Bottom sheet listing every checked item
- [ ] Pre-filled editable quantity field per item
- [ ] On confirm: call `checkoutCart()` from service
- [ ] Trigger `syncScheduler.scheduleSync()` after checkout

### D.6 — Firestore Sync for Cart

**File:** `lib/core/network/google_firestore_sync_service.dart`

- [ ] Push: `getDirtyCartItems()` → PATCH to `users/{uid}/shopping_cart_items/{id}`
- [ ] Pull: `_queryCollection('shopping_cart_items', ...)` → `upsertCartItemsBatch()`
- [ ] Add to `syncDirtyRecords()` and `pullRemoteChanges()` following the existing pattern for all other subcollections

### D.7 — Nav Entry

**File:** `lib/shared/screens/main_nav_screen.dart`

- [ ] Add `_MenuTile` for "Shopping Cart" in `MoreMenuScreen`
- [ ] Link to `ShoppingCartScreen`

### D.8 — "Add to Cart" Buttons on Existing Cards

**File:** `lib/features/nutrition/nutrient_pace_card.dart`
- [ ] When `missing_ingredients` list is present on a candidate recipe, add "Add to Cart" button per ingredient → calls `ShoppingCartService.addToCart(addedFrom: "recipe_suggestion")`

**File:** wherever shopping list card is rendered (create if not exists)
- [ ] Shopping list card showing `structural_gaps_detail` from backend
- [ ] Per-gap "Add to Cart" button → `addedFrom: "nutrient_gap"`, `reason: "Unlocks {recipe_name}"`
- [ ] Per-shopping-list item "Add to Cart" → `addedFrom: "shopping_list"`

### D.9 — Flutter Tests

**Create:** `test/shopping_cart_service_test.dart`
- [ ] Duplicate prevention (same canonical_name from two different `addedFrom` sources → only one row)
- [ ] Three entry points each produce correct `addedFrom` value

**Create:** `test/cart_checkout_test.dart`
- [ ] Checkout increments existing inventory item (doesn't duplicate)
- [ ] Checkout creates new inventory item when not found
- [ ] Unchecked items survive checkout
- [ ] Only checked items are cleared

---

## ❌ Firestore Rules

**File:** `firestore.rules`
- [ ] Add `shopping_cart_items` subcollection rules (same pattern as `diary_entries`)
- [ ] Add `shopping_lists` subcollection rules (read/write for owner only)

---

## Manual End-to-End Verification Checklist

After all above is done, verify the full loop:

1. Remove spinach from inventory
2. Trigger shopping list job → structural iron gap appears with "unlocks X"
3. Tap "Add to Cart" on gap → appears in Cart screen with reason chip
4. Trigger pacing alert mentioning spinach → confirm NO duplicate cart row created
5. Check spinach in Cart → tap "Finish Shopping" → edit quantity → confirm
6. Verify Inventory screen now shows spinach entry incremented
7. Re-trigger shopping list job → iron gap is now resolved ✓
