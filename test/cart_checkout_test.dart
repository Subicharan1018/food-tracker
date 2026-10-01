import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  group('CartCheckout — increment existing inventory item', () {
    test('checkout increments quantity on existing inventory row — does NOT duplicate', () async {
      // Pre-seed inventory with spinach
      await db.createInventoryItem(
        InventoryItemsCompanion.insert(
          name: 'Spinach',
          canonicalName: 'spinach',
          quantity: const Value(200.0),
          unit: const Value('g'),
        ),
      );

      // Add spinach to cart and mark as checked
      final cartItem = await service.addToCart(
        name: 'Spinach',
        canonicalName: 'spinach',
        addedFrom: 'nutrient_gap',
        quantity: 100.0,
        unit: 'g',
      );
      await service.toggleChecked(cartItem!.id, true);

      final checkedItems = (await db.getAllCartItems())
          .where((i) => i.checked)
          .toList();

      await service.checkoutCart(checkedItems);

      final inventory = await db.getAllInventoryItems();
      final spinachRows =
          inventory.where((i) => i.canonicalName == 'spinach').toList();

      // Must be exactly one row, not two
      expect(spinachRows.length, 1,
          reason: 'Checkout must increment, never duplicate');
      // 200 + 100 = 300
      expect(spinachRows.first.quantity, 300.0);
    });
  });

  group('CartCheckout — create new inventory item when not found', () {
    test('checkout creates new inventory row when canonical name has no match', () async {
      // Cart item whose canonical name does NOT exist in inventory
      final cartItem = await service.addToCart(
        name: 'Oats',
        canonicalName: 'oats',
        addedFrom: 'shopping_list',
        quantity: 500.0,
        unit: 'g',
      );
      await service.toggleChecked(cartItem!.id, true);

      final checkedItems = (await db.getAllCartItems())
          .where((i) => i.checked)
          .toList();

      await service.checkoutCart(checkedItems);

      final inventory = await db.getAllInventoryItems();
      final oatRows =
          inventory.where((i) => i.canonicalName == 'oats').toList();

      expect(oatRows.length, 1);
      expect(oatRows.first.quantity, 500.0);
      expect(oatRows.first.name, 'Oats');
    });
  });

  group('CartCheckout — only checked items are cleared', () {
    test('unchecked items survive checkout; checked items are deleted', () async {
      // Add two items: one checked, one unchecked
      final checked = await service.addToCart(
        name: 'Carrot',
        canonicalName: 'carrot',
        addedFrom: 'manual',
      );
      await service.addToCart(
        name: 'Broccoli',
        canonicalName: 'broccoli',
        addedFrom: 'manual',
      );

      // Only mark carrot as checked
      await service.toggleChecked(checked!.id, true);

      final checkedItems = (await db.getAllCartItems())
          .where((i) => i.checked)
          .toList();

      // Checkout the checked items
      await service.checkoutCart(checkedItems);

      final remaining = await db.getAllCartItems();

      // Carrot should be gone, broccoli must survive
      expect(remaining.any((i) => i.canonicalName == 'carrot'), false,
          reason: 'Checked item (carrot) must be deleted after checkout');
      expect(remaining.any((i) => i.canonicalName == 'broccoli'), true,
          reason: 'Unchecked item (broccoli) must survive checkout');
    });

    test('partial checkout: mixed checked/unchecked list handles both correctly', () async {
      // Three items — only the middle one is checked
      await service.addToCart(
        name: 'Tomato',
        canonicalName: 'tomato',
        addedFrom: 'manual',
      );
      final b = await service.addToCart(
        name: 'Onion',
        canonicalName: 'onion',
        addedFrom: 'shopping_list',
      );
      await service.addToCart(
        name: 'Garlic',
        canonicalName: 'garlic',
        addedFrom: 'recipe_suggestion',
      );

      await service.toggleChecked(b!.id, true);

      final checkedItems = (await db.getAllCartItems())
          .where((i) => i.checked)
          .toList();
      await service.checkoutCart(checkedItems);

      final remaining = await db.getAllCartItems();
      expect(remaining.any((i) => i.canonicalName == 'onion'), false);
      expect(remaining.any((i) => i.canonicalName == 'tomato'), true);
      expect(remaining.any((i) => i.canonicalName == 'garlic'), true);
      expect(remaining.length, 2);

      // Inventory should have onion with default qty (1)
      final inventory = await db.getAllInventoryItems();
      expect(inventory.any((i) => i.canonicalName == 'onion'), true);
      expect(inventory.any((i) => i.canonicalName == 'tomato'), false);
      expect(inventory.any((i) => i.canonicalName == 'garlic'), false);
    });
  });

  group('CartCheckout — quantity from cart item is used for new inventory row', () {
    test('quantity specified in cart is reflected in new inventory entry', () async {
      final cartItem = await service.addToCart(
        name: 'Lentils',
        canonicalName: 'lentils',
        addedFrom: 'shopping_list',
        quantity: 250.0,
        unit: 'g',
      );
      await service.toggleChecked(cartItem!.id, true);

      final checkedItems = (await db.getAllCartItems())
          .where((i) => i.checked)
          .toList();
      await service.checkoutCart(checkedItems);

      final inventory = await db.getAllInventoryItems();
      final lentils =
          inventory.firstWhere((i) => i.canonicalName == 'lentils');
      expect(lentils.quantity, 250.0);
      expect(lentils.unit, 'g');
    });
  });

  group('CartCheckout — canonicalName matching is exact', () {
    test('two items with different canonical names create two separate inventory rows', () async {
      final a = await service.addToCart(
        name: 'Brown rice',
        canonicalName: 'brown_rice',
        addedFrom: 'manual',
      );
      final b = await service.addToCart(
        name: 'White rice',
        canonicalName: 'white_rice',
        addedFrom: 'manual',
      );

      await service.toggleChecked(a!.id, true);
      await service.toggleChecked(b!.id, true);

      final checkedItems = (await db.getAllCartItems())
          .where((i) => i.checked)
          .toList();
      await service.checkoutCart(checkedItems);

      final inventory = await db.getAllInventoryItems();
      expect(inventory.where((i) => i.canonicalName == 'brown_rice').length, 1);
      expect(inventory.where((i) => i.canonicalName == 'white_rice').length, 1);
    });
  });

  group('CartCheckout — what was actually bought', () {
    Future<ShoppingCartItem> checkedItem(String name, {double qty = 1, String unit = 'pieces'}) async {
      final item = await service.addToCart(name: name, addedFrom: 'manual', quantity: qty, unit: unit);
      await service.toggleChecked(item!.id, true);
      return (await db.getCartItem(item.id))!;
    }

    test('edited quantity from the sheet is what lands in the pantry', () async {
      final item = await checkedItem('Paneer', qty: 200, unit: 'g');
      await service.checkoutCart([item.copyWith(quantity: 400)]);
      final pantry = await db.getAllInventoryItems();
      expect(pantry.single.quantity, 400);
    });

    test('a synonym in the cart increments the existing pantry row', () async {
      await db.createInventoryItem(InventoryItemsCompanion.insert(
        name: 'Spinach',
        canonicalName: 'spinach',
        quantity: const Value(250.0),
        unit: const Value('g'),
      ));
      final keerai = await checkedItem('Keerai', qty: 250, unit: 'g');
      expect(keerai.canonicalName, 'spinach');
      await service.checkoutCart([keerai]);
      final pantry = await db.getAllInventoryItems();
      expect(pantry.length, 1);
      expect(pantry.single.quantity, 500);
    });

    test('same ingredient in a different unit becomes its own row instead of corrupting the sum', () async {
      await db.createInventoryItem(InventoryItemsCompanion.insert(
        name: 'Coriander',
        canonicalName: 'coriander',
        quantity: const Value(100.0),
        unit: const Value('g'),
      ));
      await service.checkoutCart([await checkedItem('Coriander', qty: 2)]);
      final rows = (await db.getAllInventoryItems()).where((i) => i.canonicalName == 'coriander').toList();
      expect(rows.map((m) => '${m.quantity} ${m.unit}').toSet(), {'100.0 g', '2.0 pieces'});
    });

    test('an item ticked after the sheet opened is not cleared without reaching the pantry', () async {
      final eggs = await checkedItem('Eggs', qty: 12);
      final late = await checkedItem('Curd', qty: 400, unit: 'g');
      await service.checkoutCart([eggs]); // sheet was opened before curd was ticked
      final cart = await db.getAllCartItems();
      expect(cart.map((c) => c.id), [late.id]);
    });

    test('compatible units convert into the existing row (1 kg onto 500 g)', () async {
      await db.createInventoryItem(InventoryItemsCompanion.insert(
        name: 'Onion',
        canonicalName: 'onion',
        quantity: const Value(500.0),
        unit: const Value('g'),
      ));
      await service.checkoutCart([await checkedItem('Onions', qty: 1, unit: 'kg')]);
      final onion = (await db.getAllInventoryItems()).single;
      expect('${onion.quantity} ${onion.unit}', '1500.0 g');
    });

    test('quantity 0 clears the row from the list without adding stock', () async {
      final item = await checkedItem('Rajma', qty: 500, unit: 'g');
      await service.checkoutCart([item.copyWith(quantity: 0)]);
      expect(await db.getAllInventoryItems(), isEmpty);
      expect(await db.getAllCartItems(), isEmpty);
    });
  });
}
