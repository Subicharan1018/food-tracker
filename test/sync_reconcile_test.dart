import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/local_db/app_database.dart';

ShoppingCartItemsCompanion _remote(String id, String name, {bool checked = false}) => ShoppingCartItemsCompanion(
      id: Value(id),
      name: Value(name),
      canonicalName: Value(name.toLowerCase()),
      addedFrom: const Value('manual'),
      checked: Value(checked),
      isDirty: const Value(false),
      pendingDelete: const Value(false),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('pull keeps remote ids, so repeated pulls never duplicate rows', () async {
    await db.reconcileCartItems([_remote('a', 'Spinach'), _remote('b', 'Rajma')]);
    await db.reconcileCartItems([_remote('a', 'Spinach'), _remote('b', 'Rajma')]);
    expect((await db.getAllCartItems()).map((c) => c.id).toSet(), {'a', 'b'});
  });

  test('a row deleted on another device disappears locally', () async {
    await db.reconcileCartItems([_remote('a', 'Spinach'), _remote('b', 'Rajma')]);
    await db.reconcileCartItems([_remote('a', 'Spinach')]);
    expect((await db.getAllCartItems()).map((c) => c.id), ['a']);
  });

  test('unpushed local edits win over the remote copy and are never dropped', () async {
    await db.reconcileCartItems([_remote('a', 'Spinach')]);
    await db.updateCartItem('a', const ShoppingCartItemsCompanion(checked: Value(true))); // dirty
    final local = await db.insertCartItem(ShoppingCartItemsCompanion.insert(
      name: 'Curd',
      canonicalName: 'curd',
      addedFrom: 'manual',
    ));

    await db.reconcileCartItems([_remote('a', 'Spinach', checked: false)]);

    final rows = {for (final r in await db.getAllCartItems()) r.id: r};
    expect(rows['a']!.checked, isTrue);
    expect(rows.containsKey(local.id), isTrue, reason: 'not yet pushed, so absent remotely');
  });

  test('pantry reconciles the same way', () async {
    final row = InventoryItemsCompanion(
      id: const Value('p1'),
      name: const Value('Oats'),
      canonicalName: const Value('oats'),
      quantity: const Value(500.0),
      unit: const Value('g'),
      isDirty: const Value(false),
      pendingDelete: const Value(false),
    );
    await db.reconcileInventory([row]);
    await db.reconcileInventory([row]);
    expect((await db.getAllInventoryItems()).single.quantity, 500);
    await db.reconcileInventory([]);
    expect(await db.getAllInventoryItems(), isEmpty);
  });

  test('v2 databases migrate to text ids without losing cart or pantry rows', () async {
    final v2 = NativeDatabase.memory(setup: (raw) {
      raw.execute('''CREATE TABLE inventory_items (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, canonical_name TEXT NOT NULL, quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT NOT NULL DEFAULT 'pieces', updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        is_dirty INTEGER NOT NULL DEFAULT 1)''');
      raw.execute('''CREATE TABLE shopping_cart_items (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, canonical_name TEXT NOT NULL, quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT NOT NULL DEFAULT 'pieces', added_from TEXT NOT NULL, reason TEXT NULL,
        checked INTEGER NOT NULL DEFAULT 0, added_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        is_dirty INTEGER NOT NULL DEFAULT 1)''');
      raw.execute('''CREATE TABLE recipes (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, tamil_name TEXT NULL,
        meal_slot TEXT NOT NULL, day_of_week TEXT NULL, calories REAL NOT NULL, protein_g REAL NOT NULL,
        carbs_g REAL NOT NULL, fat_g REAL NOT NULL, fiber_g REAL NOT NULL DEFAULT 0.0, ingredients_json TEXT NOT NULL,
        method TEXT NOT NULL, shelf_life_tip TEXT NULL, tags TEXT NULL,
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)))''');
      raw.execute("INSERT INTO recipes (id, name, meal_slot, calories, protein_g, carbs_g, fat_g, ingredients_json, method) VALUES ('r1', 'Rajma', 'lunch', 400, 20, 50, 8, '[]', '')");
      raw.execute("INSERT INTO inventory_items (name, canonical_name, quantity, unit) VALUES ('Oats', 'oats', 500, 'g')");
      raw.execute("INSERT INTO shopping_cart_items (name, canonical_name, added_from, reason) VALUES ('Rajma', 'kidney beans', 'nutrient_gap', 'Unlocks Rajma Masala')");
      raw.execute('PRAGMA user_version = 2');
    });
    await db.close();
    db = AppDatabase(v2);
    final pantry = await db.getAllInventoryItems();
    final cart = await db.getAllCartItems();
    expect(pantry.single.id, '1');
    expect(pantry.single.pendingDelete, isFalse);
    expect(cart.single.reason, 'Unlocks Rajma Masala');
    expect(cart.single.id, '1');
    // v5: existing recipes get servings = 1; later tables exist.
    expect((await db.getAllRecipes()).single.servings, 1.0);
    expect(await db.getPendingDeletions(), isEmpty);
  });
}
