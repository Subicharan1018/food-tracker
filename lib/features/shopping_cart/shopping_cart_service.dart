import 'package:drift/drift.dart';
import '../../core/ingredients/ingredient_identity.dart';
import '../../core/local_db/app_database.dart';
import '../../core/sync/sync_scheduler.dart';

/// Where a cart row came from.  Stored as plain strings so the backend and
/// Firestore documents stay readable.
abstract final class CartSource {
  static const shoppingList = 'shopping_list';
  static const nutrientGap = 'nutrient_gap';
  static const recipeSuggestion = 'recipe_suggestion';
  static const manual = 'manual';
}

/// Unified shopping cart service.
/// All entry points (shopping_list, nutrient_gap, recipe_suggestion, manual)
/// funnel through a single [addToCart] method — deduplication by canonical
/// name is enforced here, never at the call site.
class ShoppingCartService {
  final AppDatabase _db;
  final SyncScheduler? _syncScheduler;

  ShoppingCartService(this._db, [this._syncScheduler]);

  // ── Read ──────────────────────────────────────────────────────────────────

  Stream<List<ShoppingCartItem>> watchCartItems() => _db.watchCartItems();

  Future<List<ShoppingCartItem>> getAllCartItems() => _db.getAllCartItems();

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Add an item to the cart.
  ///
  /// [canonicalName] defaults to [canonicalizeIngredient] of [name]; a
  /// supplied value (e.g. the backend's `canonical_name`) is canonicalized
  /// again so both sides always agree.
  ///
  /// If an unchecked row for the same ingredient already exists — whichever
  /// feature added it — that row is returned instead of inserting a
  /// duplicate.  A reason is attached if the existing row had none.
  Future<ShoppingCartItem?> addToCart({
    required String name,
    String? canonicalName,
    double quantity = 1.0,
    String unit = 'pieces',
    required String addedFrom,
    String? reason,
  }) async {
    final canonical = canonicalizeIngredient(canonicalName ?? name);
    if (canonical.isEmpty) return null;

    final existing = await _db.getCartItemByCanonicalName(canonical);
    if (existing != null) {
      if ((existing.reason == null || existing.reason!.isEmpty) && reason != null) {
        await _db.updateCartItem(existing.id, ShoppingCartItemsCompanion(reason: Value(reason)));
        _syncScheduler?.scheduleSync();
        return _db.getCartItem(existing.id);
      }
      return existing;
    }

    final row = await _db.insertCartItem(
      ShoppingCartItemsCompanion.insert(
        name: name.trim(),
        canonicalName: canonical,
        quantity: Value(quantity),
        unit: Value(unit),
        addedFrom: addedFrom,
        reason: Value(reason),
      ),
    );
    _syncScheduler?.scheduleSync();
    return row;
  }

  /// Toggle the checked/unchecked state of a cart item.
  Future<void> toggleChecked(String id, bool checked) async {
    await _db.updateCartItem(id, ShoppingCartItemsCompanion(checked: Value(checked)));
    _syncScheduler?.scheduleSync();
  }

  Future<void> updateQuantity(String id, double quantity, String unit) async {
    await _db.updateCartItem(
      id,
      ShoppingCartItemsCompanion(quantity: Value(quantity), unit: Value(unit)),
    );
    _syncScheduler?.scheduleSync();
  }

  /// Remove a single cart item (swipe-to-delete).
  Future<void> removeItem(String id) => _db.deleteCartItem(id);

  /// Undo a swipe-delete before or after it has synced.
  Future<void> restoreItem(ShoppingCartItem item) async {
    await _db.into(_db.shoppingCartItems).insertOnConflictUpdate(
          item.copyWith(pendingDelete: false, isDirty: true, updatedAt: DateTime.now()),
        );
    _syncScheduler?.scheduleSync();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  /// For each checked item:
  ///   - Increment the pantry row with the same canonical name and a
  ///     compatible unit (converted), OR
  ///   - Create a new pantry row if none exists.
  /// Then delete exactly those cart rows — unchecked rows survive.
  ///
  /// [checkedItems] carry the quantities the user actually bought, which may
  /// differ from what was suggested.  Runs in one transaction and syncs
  /// immediately so the next backend job sees the new stock.
  Future<void> checkoutCart(List<ShoppingCartItem> checkedItems) async {
    if (checkedItems.isEmpty) return;
    await _db.transaction(() async {
      for (final item in checkedItems) {
        if (item.quantity <= 0) continue;
        final canonical = canonicalizeIngredient(item.canonicalName);
        // Merge into a row whose unit converts (1 kg onto 500 g); an
        // incompatible unit (2 bunches vs 500 g) gets its own row rather
        // than corrupting the sum — the backend converts each row itself.
        InventoryItem? target;
        double? converted;
        for (final row in await _db.getInventoryItemsByCanonicalName(canonical)) {
          converted = convertQuantity(item.quantity, item.unit, row.unit);
          if (converted != null) {
            target = row;
            break;
          }
        }
        if (target != null) {
          await _db.incrementInventoryQuantity(target.id, converted!);
        } else {
          await _db.createInventoryItem(
            InventoryItemsCompanion.insert(
              name: item.name,
              canonicalName: canonical,
              quantity: Value(item.quantity),
              unit: Value(item.unit),
            ),
          );
        }
      }
      await _db.deleteCartItems(checkedItems.map((i) => i.id).toList());
    });
    await _syncScheduler?.syncNow();
  }
}

const _massOrVolume = {'g': ('g', 1.0), 'kg': ('g', 1000.0), 'ml': ('ml', 1.0), 'l': ('ml', 1000.0)};

/// [quantity] in [from] expressed in [to], or `null` when the units don't convert.
double? convertQuantity(double quantity, String from, String to) {
  if (from == to) return quantity;
  final a = _massOrVolume[from];
  final b = _massOrVolume[to];
  if (a == null || b == null || a.$1 != b.$1) return null;
  return quantity * a.$2 / b.$2;
}
