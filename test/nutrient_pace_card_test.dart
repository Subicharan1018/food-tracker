import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/nutrition/nutrient_pace_card.dart';
import 'package:food_tracker/features/shopping_cart/shopping_cart_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> status) => tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            shoppingCartServiceProvider.overrideWithValue(ShoppingCartService(db)),
          ],
          child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: NutrientPaceCard(status: status)))),
        ),
      );

  Map<String, dynamic> status({required bool makeable}) => {
        'updated_at': '2026-10-01T17:00:00Z',
        'message': 'Make Rajma Masala tonight.',
        'issues': {
          'nutrient_gaps': {
            'iron_mg': {'consumed': 4.1, 'expected': 11.4},
          },
        },
        'candidate_recipe': {
          'name': 'Rajma Masala',
          'nutrient': 'iron_mg',
          'per_serving_amount': 6.2,
          'makeable': makeable,
          'missing_ingredients': makeable
              ? []
              : [
                  {'name': 'Rajma', 'canonical_name': 'kidney beans', 'quantity': 100, 'unit': 'g'},
                ],
        },
      };

  testWidgets('shows server numbers and adds the missing ingredient as a recipe suggestion', (tester) async {
    await tester.runAsync(() async {
      await pump(tester, status(makeable: false));
      await tester.pump();

      expect(find.text('Iron'), findsOneWidget);
      expect(find.textContaining('4.1'), findsOneWidget);
      expect(find.text('Closest fix'), findsOneWidget);
      expect(find.text('Needs Rajma'), findsOneWidget);

      await tester.tap(find.text('+ Add'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();

      final row = (await db.getAllCartItems()).single;
      expect(row.canonicalName, 'kidney beans');
      expect(row.addedFrom, CartSource.recipeSuggestion);
      expect(row.reason, 'Unlocks Rajma Masala');
      expect(row.quantity, 100);
      expect(row.unit, 'g');
      expect(find.text('In cart'), findsOneWidget);
    });
    await _unmount(tester);
  });

  testWidgets('makeable candidate offers no shopping, just the fix', (tester) async {
    await tester.runAsync(() async {
      await pump(tester, status(makeable: true));
      await tester.pump();
      expect(find.text('Fix with what you have'), findsOneWidget);
      expect(find.text('+ Add'), findsNothing);
    });
    await _unmount(tester);
  });

  testWidgets('no status yet explains the schedule instead of showing zeros', (tester) async {
    await tester.runAsync(() async {
      await pump(tester, const {});
      await tester.pump();
      expect(find.textContaining('No check has run yet'), findsOneWidget);
      expect(find.textContaining('0 /'), findsNothing);
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
