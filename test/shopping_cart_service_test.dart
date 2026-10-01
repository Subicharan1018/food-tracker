import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/shopping_cart/shopping_cart_service.dart';

void main() {
  late AppDatabase db;
  late ShoppingCartService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ShoppingCartService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ShoppingCartService — addToCart', () {
    test('adds a new item and returns it', () async {
      final item = await service.addToCart(
        name: 'Spinach',
        canonicalName: 'spinach',
        addedFrom: 'shopping_list',
      );
      expect(item, isNotNull);
      expect(item!.name, 'Spinach');
      expect(item.canonicalName, 'spinach');
      expect(item.addedFrom, 'shopping_list');
      expect(item.checked, false);
    });

    test('deduplicates: same canonicalName from two different addedFrom sources → only one row', () async {
      // First add from shopping_list
      await service.addToCart(
        name: 'Spinach',
        canonicalName: 'spinach',
        addedFrom: 'shopping_list',
      );

      // Second add from nutrient_gap — must NOT create a duplicate
      await service.addToCart(
        name: 'Spinach',
        canonicalName: 'spinach',
        addedFrom: 'nutrient_gap',
        reason: 'Unlocks Iron-Rich Curry',
      );

      // Third add from recipe_suggestion — also must not duplicate
      await service.addToCart(
        name: 'Spinach',
        canonicalName: 'spinach',
        addedFrom: 'recipe_suggestion',
        reason: 'Unlocks Keerai Kootu',
      );

      final allItems = await db.getAllCartItems();
      final spinachRows =
          allItems.where((i) => i.canonicalName == 'spinach').toList();
      expect(spinachRows.length, 1,
          reason: 'Only one cart row should exist regardless of addedFrom source');
      // The surviving row should be the first one inserted (shopping_list)
      expect(spinachRows.first.addedFrom, 'shopping_list');
    });

    test('addedFrom: shopping_list produces correct tag', () async {
      final item = await service.addToCart(
        name: 'Oats',
        canonicalName: 'oats',
        addedFrom: 'shopping_list',
      );
      expect(item?.addedFrom, 'shopping_list');
    });

    test('addedFrom: nutrient_gap produces correct tag with reason', () async {
      final item = await service.addToCart(
        name: 'Salmon',
        canonicalName: 'salmon',
        addedFrom: 'nutrient_gap',
        reason: 'Unlocks Fish Curry',
      );
      expect(item?.addedFrom, 'nutrient_gap');
      expect(item?.reason, 'Unlocks Fish Curry');
    });

    test('addedFrom: recipe_suggestion produces correct tag with reason', () async {
      final item = await service.addToCart(
        name: 'Methi leaves',
        canonicalName: 'methi_leaves',
        addedFrom: 'recipe_suggestion',
        reason: 'Unlocks Methi Paratha',
      );
      expect(item?.addedFrom, 'recipe_suggestion');
      expect(item?.reason, 'Unlocks Methi Paratha');
    });

    test('addedFrom: manual produces no reason', () async {
      final item = await service.addToCart(
        name: 'Toothpaste',
        canonicalName: 'toothpaste',
        addedFrom: 'manual',
      );
      expect(item?.addedFrom, 'manual');
      expect(item?.reason, isNull);
    });

    test('checked item with same canonicalName allows a new unchecked row', () async {
      // Add and check the item (simulate already bought)
      final item = await service.addToCart(
        name: 'Turmeric',
        canonicalName: 'turmeric',
        addedFrom: 'shopping_list',
      );
      await service.toggleChecked(item!.id, true);

      // Now add again — existing row is checked, so a new unchecked row is OK
      final item2 = await service.addToCart(
        name: 'Turmeric',
        canonicalName: 'turmeric',
        addedFrom: 'nutrient_gap',
      );
      // Since the existing row IS checked, the dedup query won't find it
      // (dedup only matches unchecked rows), so a new row should be created
      final allItems = await db.getAllCartItems();
      final turmericRows = allItems.where((i) => i.canonicalName == 'turmeric').toList();
      expect(turmericRows.length, 2,
          reason: 'A checked row and a new unchecked row can coexist');
      expect(item2, isNotNull);
    });
  });

  group('ShoppingCartService — toggleChecked', () {
    test('toggles item checked state', () async {
      final item = await service.addToCart(
        name: 'Broccoli',
        canonicalName: 'broccoli',
        addedFrom: 'manual',
      );
      await service.toggleChecked(item!.id, true);

      final all = await db.getAllCartItems();
      expect(all.first.checked, true);

      await service.toggleChecked(item.id, false);
      final all2 = await db.getAllCartItems();
      expect(all2.first.checked, false);
    });
  });

  group('ShoppingCartService — removeItem', () {
    test('removes a specific item by id', () async {
      final item = await service.addToCart(
        name: 'Ginger',
        canonicalName: 'ginger',
        addedFrom: 'manual',
      );
      await service.removeItem(item!.id);
      final all = await db.getAllCartItems();
      expect(all.where((i) => i.canonicalName == 'ginger').isEmpty, true);
    });
  });

  group('ShoppingCartService — watchCartItems', () {
    test('emits updated list reactively when items change', () async {
      final stream = service.watchCartItems();

      // Seed first item
      await service.addToCart(
        name: 'Tomato',
        canonicalName: 'tomato',
        addedFrom: 'manual',
      );

      final first = await stream.first;
      expect(first.any((i) => i.canonicalName == 'tomato'), true);
    });
  });

  group('ShoppingCartService — canonical identity', () {
    test('regional synonyms dedupe: Palak from a gap and Keerai from a recipe are one row', () async {
      await service.addToCart(name: 'Palak', addedFrom: 'nutrient_gap', reason: 'Unlocks Palak Paneer');
      await service.addToCart(name: 'Keerai', addedFrom: 'recipe_suggestion', reason: 'Unlocks Keerai Kootu');
      await service.addToCart(name: 'Spinach', canonicalName: 'spinach', addedFrom: 'shopping_list');
      final rows = await db.getAllCartItems();
      expect(rows.length, 1);
      expect(rows.single.canonicalName, 'spinach');
      expect(rows.single.reason, 'Unlocks Palak Paneer', reason: 'first reason is kept');
    });

    test('a reason is attached when a manual row is later suggested by a gap', () async {
      await service.addToCart(name: 'Rajma', addedFrom: 'manual');
      final merged = await service.addToCart(name: 'rajma', addedFrom: 'nutrient_gap', reason: 'Unlocks Rajma Masala');
      expect((await db.getAllCartItems()).length, 1);
      expect(merged!.reason, 'Unlocks Rajma Masala');
    });

    test('blank names are ignored', () async {
      expect(await service.addToCart(name: '   ', addedFrom: 'manual'), isNull);
      expect(await db.getAllCartItems(), isEmpty);
    });
  });

  group('ShoppingCartService — delete propagation', () {
    test('removed rows are tombstoned for sync, hidden locally, and restorable', () async {
      final item = await service.addToCart(name: 'Curd', addedFrom: 'manual');
      await db.markCartItemsClean([item!.id]);
      await service.removeItem(item.id);

      expect(await db.getAllCartItems(), isEmpty);
      final tombstone = (await db.getDirtyCartItems()).single;
      expect(tombstone.pendingDelete, isTrue, reason: 'push must DELETE the remote doc');

      // Re-adding the same ingredient must not resurrect the tombstone.
      await service.addToCart(name: 'Curd', addedFrom: 'manual');
      expect((await db.getAllCartItems()).length, 1);

      await service.restoreItem(item);
      expect((await db.getAllCartItems()).length, 2);
    });
  });
}
