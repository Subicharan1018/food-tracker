import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/ai_planner/meal_plan_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('shows and logs the recipe box numbers, never the AI\'s', (tester) async {
    await tester.runAsync(() async {
      await db.into(db.recipes).insert(RecipesCompanion.insert(
            id: 'biryani',
            name: 'Chicken Biryani',
            mealSlot: 'dinner',
            calories: 612,
            proteinG: 48,
            carbsG: 70,
            fatG: 15,
            ingredientsJson: '[]',
            method: '',
          ));

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: Scaffold(
            body: MealPlanCard(planItems: [
              // The AI's own numbers are deliberately different and must be ignored.
              {'recipe_name': 'chicken biryani', 'meal_slot': 'dinner', 'calories': 550, 'protein': 42, 'reasoning': 'High protein'},
              {'recipe_name': 'Grilled Salmon', 'meal_slot': 'dinner', 'calories': 400, 'protein': 35},
            ]),
          ),
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();

      expect(find.text('Chicken Biryani'), findsOneWidget);
      expect(find.text('612 kcal · 48 g protein'), findsOneWidget);
      expect(find.textContaining('550'), findsNothing);
      expect(find.textContaining('Not in your recipe box'), findsOneWidget);
      expect(find.text('Log meal'), findsOneWidget, reason: 'only the matched recipe can be logged');

      await tester.tap(find.text('Log meal'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();

      final entry = (await db.select(db.diaryEntries).get()).single;
      expect(entry.foodName, 'Chicken Biryani');
      expect(entry.calories, 612);
      expect(entry.proteinG, 48);
      expect(find.text('Logged'), findsOneWidget);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
