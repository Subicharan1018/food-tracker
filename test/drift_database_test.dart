import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/core/local_db/seed_data.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift In-Memory Database Tests', () {
    test('Seeds default user profile, foods, activities, and recipes', () async {
      await SeedData.seedInitialData(db);

      final user = await db.getUserProfile();
      expect(user, isNotNull);
      expect(user!.calorieTarget, 2350);
      expect(user.proteinTargetG, 155.0);
      expect(user.carbTargetG, 260.0);
      expect(user.fatTargetG, 70.0);

      final foods = await db.searchFoodItems('chicken');
      expect(foods.isNotEmpty, true);

      final recipes = await db.getAllRecipes();
      expect(recipes.isNotEmpty, true);
      expect(recipes.any((r) => r.name.contains('Naatu Kozhi')), true);
    });

    test('Adds diary entries and computes macro source breakdown', () async {
      await SeedData.seedInitialData(db);

      const dateStr = '2026-09-05';

      // 1. Log Breakfast: 4 eggs (Vengaya Muttai Poriyal)
      await db.addDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: 'entry_1',
          date: dateStr,
          mealSlot: 'breakfast',
          foodName: 'Vengaya Muttai Poriyal (4 eggs + 4 chapatis)',
          portionQty: 1.0,
          portionUnit: 'meal',
          calories: 700.0,
          proteinG: 37.0,
          carbsG: 74.0,
          fatG: 21.0,
          loggedAt: Value(DateTime.now()),
        ),
      );

      // 2. Log Lunch: Naatu Kozhi Milagu Varuval
      await db.addDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: 'entry_2',
          date: dateStr,
          mealSlot: 'lunch',
          foodName: 'Naatu Kozhi Milagu Varuval (180g Chicken)',
          portionQty: 1.0,
          portionUnit: 'box',
          calories: 530.0,
          proteinG: 44.0,
          carbsG: 51.0,
          fatG: 16.0,
          loggedAt: Value(DateTime.now()),
        ),
      );

      // 3. Log Whey Shake at bus stop
      await db.addDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: 'entry_3',
          date: dateStr,
          mealSlot: 'shake',
          foodName: 'Whey Protein Isolate',
          portionQty: 1.0,
          portionUnit: 'scoop',
          calories: 120.0,
          proteinG: 24.0,
          carbsG: 2.0,
          fatG: 1.5,
          loggedAt: Value(DateTime.now()),
        ),
      );

      final entries = await db.getEntriesForDate(dateStr);
      expect(entries.length, 3);

      final totalCalories = entries.fold<double>(0, (sum, e) => sum + e.calories);
      final totalProtein = entries.fold<double>(0, (sum, e) => sum + e.proteinG);
      final totalCarbs = entries.fold<double>(0, (sum, e) => sum + e.carbsG);

      expect(totalCalories, 1350.0);
      expect(totalProtein, 105.0);
      expect(totalCarbs, 127.0);

      // Verify Macro Source Breakdown attribution:
      // Protein sources:
      // - Naatu Kozhi: 44g
      // - Vengaya Muttai: 37g
      // - Whey Protein: 24g
      final sortedProteinSources = List<DiaryEntry>.from(entries)
        ..sort((a, b) => b.proteinG.compareTo(a.proteinG));

      expect(sortedProteinSources.first.foodName, contains('Naatu Kozhi'));
      expect(sortedProteinSources.first.proteinG, 44.0);
      expect(sortedProteinSources[1].proteinG, 37.0);
      expect(sortedProteinSources[2].proteinG, 24.0);
    });

    test('Logs water and calculates daily total', () async {
      const dateStr = '2026-09-05';
      await db.addWaterLog(
        WaterLogsCompanion.insert(
          id: 'water_1',
          date: dateStr,
          mlAdded: 250,
        ),
      );
      await db.addWaterLog(
        WaterLogsCompanion.insert(
          id: 'water_2',
          date: dateStr,
          mlAdded: 500,
        ),
      );

      final totalWater = await db.watchWaterForDate(dateStr).first;
      expect(totalWater, 750);
    });

    test('Logs workout session and set-by-set reps and weight', () async {
      const dateStr = '2026-09-05';

      await db.addWorkoutSession(
        WorkoutSessionsCompanion.insert(
          id: 'sess_push',
          date: dateStr,
          activityName: 'Push + HIIT (Chest, Shoulders, Triceps)',
          durationMin: 60,
          caloriesBurned: 320.0,
          source: const Value('routine'),
        ),
      );

      await db.addWorkoutSetLogs([
        WorkoutSetLogsCompanion.insert(
          id: 'set_1',
          sessionId: 'sess_push',
          date: dateStr,
          exerciseName: 'Barbell Bench Press',
          setIndex: 1,
          weightKg: 24.0,
          reps: 10,
          targetReps: const Value('8-10'),
        ),
        WorkoutSetLogsCompanion.insert(
          id: 'set_2',
          sessionId: 'sess_push',
          date: dateStr,
          exerciseName: 'Barbell Bench Press',
          setIndex: 2,
          weightKg: 26.0,
          reps: 9,
          targetReps: const Value('8-10'),
        ),
      ]);

      final sets = await db.watchSetLogsForDate(dateStr).first;
      expect(sets.length, 2);
      expect(sets[0].weightKg, 24.0);
      expect(sets[0].reps, 10);
      expect(sets[1].weightKg, 26.0);
      expect(sets[1].reps, 9);
    });
  });
}
