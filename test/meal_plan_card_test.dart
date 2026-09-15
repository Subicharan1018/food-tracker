import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/ai_planner/meal_plan_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase inMemoryDb;

  setUp(() {
    inMemoryDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await inMemoryDb.close();
  });

  testWidgets('MealPlanCard renders items and logs directly to Drift database', (tester) async {
    final mockPlan = [
      {
        'recipe_name': 'Chicken Biryani',
        'meal_slot': 'dinner',
        'calories': 550,
        'protein': 42,
        'reasoning': 'Optimal high-protein evening dinner'
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealPlanCard(planItems: mockPlan),
          ),
        ),
      ),
    );

    // Verify UI components render
    expect(find.text("Tonight's Plan"), findsOneWidget);
    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('550 kcal'), findsOneWidget);
    expect(find.text('42 g protein'), findsOneWidget);
    expect(find.text('Optimal high-protein evening dinner'), findsOneWidget);

    // Tap "Log meal" button
    final logButton = find.text('Log meal');
    expect(logButton, findsOneWidget);
    await tester.tap(logButton);
    await tester.pumpAndSettle();

    // Verify written to database
    final entries = await inMemoryDb.select(inMemoryDb.diaryEntries).get();
    expect(entries.length, 1);
    expect(entries.first.foodName, 'Chicken Biryani');
    expect(entries.first.calories, 550.0);
    expect(entries.first.proteinG, 42.0);

    // Verify button state updated to Logged
    expect(find.text('Logged'), findsOneWidget);
  });
}
