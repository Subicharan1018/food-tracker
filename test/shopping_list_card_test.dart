import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/shopping_cart/shopping_cart_service.dart';
import 'package:food_tracker/features/shopping_cart/shopping_list_card.dart';

const _payload = {
  'computed_at': '2026-10-03T08:00:00Z',
  'coverage': {
    'iron_mg': {'achievable': 41.6, 'target': 133.0, 'pct': 31.3},
  },
  'structural_gaps': ['iron_mg', 'zinc_mg'],
  'unmeasured_nutrients': ['b12_mcg'],
  'missing_data': ['onion (unknown weight for \'pieces\')'],
  'sources': ['IFCT 2017 · D032'],
  'structural_gaps_detail': [
    {
      'nutrient': 'iron_mg',
      'unlocks_recipe': 'Palak Rajma',
      'per_serving_amount': 6.2,
      'missing_ingredients': [
        {'name': 'Rajma', 'canonical_name': 'kidney beans', 'quantity': 100, 'unit': 'g'},
        {'name': 'Palak', 'canonical_name': 'spinach', 'quantity': 200, 'unit': 'g'},
      ],
    },
  ],
  'shopping_list': [
    {'name': 'Rajma', 'canonical_name': 'kidney beans', 'quantity': 100, 'unit': 'g', 'unlocks': ['Palak Rajma'], 'nutrients': ['iron_mg']},
    {'name': 'Palak', 'canonical_name': 'spinach', 'quantity': 200, 'unit': 'g', 'unlocks': ['Palak Rajma'], 'nutrients': ['iron_mg']},
  ],
};

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            shoppingCartServiceProvider.overrideWithValue(ShoppingCartService(db)),
            weeklyShoppingListProvider.overrideWith((ref) async => Map<String, dynamic>.from(_payload)),
          ],
          child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ShoppingListCard()))),
        ),
      );

  testWidgets('renders cited gaps, honest gaps in data, and freshness', (tester) async {
    await tester.runAsync(() async {
      await pump(tester);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();

      expect(find.text('Iron'), findsOneWidget);
      expect(find.text('31.3% of weekly target'), findsOneWidget);
      expect(find.textContaining('Computed Sat 3 Oct'), findsOneWidget);
      expect(find.textContaining('Also low: Zinc'), findsOneWidget);
      expect(find.textContaining('No cited data in your pantry for B12'), findsOneWidget);
      expect(find.textContaining('Not counted: onion'), findsOneWidget);
      expect(find.textContaining('IFCT 2017 · D032'), findsOneWidget);
    });
    await _unmount(tester);
  });

  testWidgets('gap add writes a nutrient_gap row with the unlock reason, and flips to In cart', (tester) async {
    await tester.runAsync(() async {
      await pump(tester);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();

      await tester.tap(find.text('+ Add').first);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();

      final row = (await db.getAllCartItems()).single;
      expect(row.canonicalName, 'kidney beans');
      expect(row.addedFrom, CartSource.nutrientGap);
      expect(row.reason, 'Unlocks Palak Rajma');
      expect(find.text('In cart'), findsOneWidget);
    });
    await _unmount(tester);
  });

  testWidgets('add all uses the shopping_list source and never duplicates an existing row', (tester) async {
    await tester.runAsync(() async {
      await ShoppingCartService(db).addToCart(name: 'Keerai', addedFrom: CartSource.manual);
      await pump(tester);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await tester.pump();

      // Spinach is already in the cart (as Keerai), so only one item is left to add.
      expect(find.text('Add all 2 to cart'), findsNothing);
      await tester.tap(find.text('+ Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();

      final rows = await db.getAllCartItems();
      expect(rows.map((r) => r.canonicalName).toSet(), {'spinach', 'kidney beans'});
      expect(rows.length, 2);
    });
    await _unmount(tester);
  });
}

/// Dispose the ProviderScope and flush drift's stream-close timer, so the
/// test binding doesn't see a pending timer after the tree is gone.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}
