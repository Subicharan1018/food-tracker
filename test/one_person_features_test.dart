import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/food_logging/repeat_meal.dart';
import 'package:food_tracker/features/pantry/pantry_service.dart';
import 'package:food_tracker/features/settings/data_export.dart';
import 'package:food_tracker/features/workouts/progression_engine.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Recipe> recipe({double servings = 2}) async {
    await db.into(db.recipes).insert(RecipesCompanion.insert(
          id: 'palak_paneer',
          name: 'Palak Paneer',
          mealSlot: 'dinner',
          calories: 400,
          proteinG: 25,
          carbsG: 12,
          fatG: 28,
          servings: Value(servings),
          ingredientsJson: jsonEncode([
            {'name': 'Paneer', 'amount': 200, 'unit': 'g', 'grams': 200},
            {'name': 'Palak', 'amount': 0.5, 'unit': 'kg'},
            {'name': 'Onion', 'amount': 2, 'unit': 'piece'},
            {'name': 'Water', 'amount': 1, 'unit': 'cup'},
            {'name': 'Garam masala', 'amount': 1, 'unit': 'tsp'},
          ]),
          method: '',
        ));
    return (await db.getAllRecipes()).single;
  }

  Future<void> stock(String name, String canonical, double qty, String unit) => db.createInventoryItem(
        InventoryItemsCompanion.insert(name: name, canonicalName: canonical, quantity: Value(qty), unit: Value(unit)),
      );

  Future<Map<String, double>> pantry() async => {for (final i in await db.getAllInventoryItems()) i.canonicalName: i.quantity};

  group('cooking uses pantry stock', () {
    test('one serving of a 2-serving recipe takes half of each ingredient, in the pantry unit', () async {
      final r = await recipe();
      await stock('Paneer', 'paneer', 500, 'g');
      await stock('Spinach', 'spinach', 1, 'kg');
      await stock('Onions', 'onion', 6, 'pieces');

      final report = await logRecipe(db, r, date: '2026-10-01', mealSlot: 'dinner');

      expect(await pantry(), {'paneer': 400, 'spinach': 0.75, 'onion': 5});
      expect(report.notTracked, ['Garam masala'], reason: 'water is never tracked; masala has no pantry row');
      expect(report.summary, startsWith('Used 100 g paneer'));
      final entry = (await db.select(db.diaryEntries).get()).single;
      expect([entry.foodName, entry.calories], ['Palak Paneer', 400]);
    });

    test('stock never goes below zero', () async {
      final r = await recipe(servings: 1);
      await stock('Paneer', 'paneer', 50, 'g');
      await logRecipe(db, r, date: '2026-10-01', mealSlot: 'dinner');
      expect((await pantry())['paneer'], 0);
    });

    test('deleting the meal puts the stock back and queues the remote delete', () async {
      final r = await recipe();
      await stock('Paneer', 'paneer', 500, 'g');
      await logRecipe(db, r, date: '2026-10-01', mealSlot: 'dinner');
      final entry = (await db.select(db.diaryEntries).get()).single;

      expect(await db.deleteDiaryEntry(entry.id), isTrue);

      expect((await pantry())['paneer'], 500);
      expect(await db.getPendingDeletions(), ['diary_entries/${entry.id}']);
    });
  });

  test('repeating a meal re-logs recipes through the pantry and copies other foods with their IFCT link', () async {
    final r = await recipe();
    await stock('Paneer', 'paneer', 500, 'g');
    await logRecipe(db, r, date: '2026-09-30', mealSlot: 'dinner');
    await db.addDiaryEntry(DiaryEntriesCompanion.insert(
      id: 'curd',
      date: '2026-09-30',
      mealSlot: 'dinner',
      foodItemId: const Value('ifct_l001'),
      foodName: 'Curd',
      portionQty: 150,
      portionUnit: 'g',
      calories: 90,
      proteinG: 5,
      carbsG: 4,
      fatG: 6,
    ));

    final last = await db.lastMealsBySlot('2026-09-20', '2026-10-01');
    expect(repeatLabel(last['dinner']!), 'Same as Wed: Palak Paneer + Curd');

    await repeatMeal(db, last['dinner']!, date: '2026-10-01');

    final today = await (db.select(db.diaryEntries)..where((e) => e.date.equals('2026-10-01'))).get();
    expect(today.map((e) => e.foodName).toSet(), {'Palak Paneer', 'Curd'});
    expect(today.firstWhere((e) => e.foodName == 'Curd').foodItemId, 'ifct_l001');
    expect((await pantry())['paneer'], 300, reason: 'both dinners used paneer');
  });

  test('weigh-ins store a real 7-day rolling average and replace same-day entries', () async {
    await db.saveWeighIn('2026-09-25', 63.0);
    await db.saveWeighIn('2026-09-28', 62.0);
    await db.saveWeighIn('2026-10-01', 61.6);
    await db.saveWeighIn('2026-10-01', 61.0); // re-weigh same morning
    final rows = await db.select(db.weighIns).get();
    final today = rows.singleWhere((w) => w.date == '2026-10-01');
    expect(rows.length, 3);
    expect(today.weightKg, 61.0);
    expect(today.rollingAvgKg, closeTo((63.0 + 62.0 + 61.0) / 3, 0.01));
  });

  test('export contains every table with readable dates', () async {
    await db.saveWeighIn('2026-10-01', 61.0);
    final data = await buildExport(db);
    expect(data.keys, containsAll(['diaryEntries', 'weighIns', 'sleepLogs', 'pantry', 'recipes']));
    expect((data['weighIns'] as List).single['loggedAt'], isA<String>());
    expect(() => jsonEncode(data), returnsNormally);
  });

  group('progression rules from the manual', () {
    WorkoutSetLog set(String date, double kg, int reps, {String exercise = 'Barbell bench press'}) => WorkoutSetLog(
          id: '$date-$kg-$reps-${DateTime.now().microsecondsSinceEpoch}',
          sessionId: 's',
          date: date,
          exerciseName: exercise,
          setIndex: 1,
          weightKg: kg,
          reps: reps,
          completed: true,
          loggedAt: DateTime(2026),
          isDirty: false,
        );
    List<WorkoutSetLog> session(String date, double kg, List<int> reps, {String exercise = 'Barbell bench press'}) =>
        [for (final r in reps) set(date, kg, r, exercise: exercise)];

    test('top of the range two sessions running → add the smallest plate', () {
      final p = recommendProgression(
        exercise: 'Barbell bench press',
        setsReps: '4 × 8–10',
        history: [...session('2026-09-21', 20, [10, 10, 10, 10]), ...session('2026-09-28', 20, [10, 10, 10, 10])],
      )!;
      expect(p.headline, 'Go to 22 kg');
    });

    test('once at the top → repeat before adding load', () {
      final p = recommendProgression(
        exercise: 'Barbell bench press',
        setsReps: '4 × 8–10',
        history: [...session('2026-09-21', 20, [10, 9, 8, 8]), ...session('2026-09-28', 20, [10, 10, 10, 10])],
      )!;
      expect(p.headline, 'Repeat 20 kg');
    });

    test('bar maxed at 26 kg → tempo instead of load', () {
      final p = recommendProgression(
        exercise: 'Barbell back squat',
        setsReps: '4 × 8–10',
        usesBar: true,
        history: [
          ...session('2026-09-21', 26, [10, 10, 10, 10], exercise: 'Barbell back squat'),
          ...session('2026-09-28', 26, [10, 10, 10, 10], exercise: 'Barbell back squat'),
        ],
      )!;
      expect(p.headline, startsWith('Bar is maxed'));
    });

    test('three weeks flat → stall, pointing at sleep first', () {
      final p = recommendProgression(
        exercise: 'Barbell bench press',
        setsReps: '4 × 8–10',
        averageSleepHours: 6.2,
        history: [
          ...session('2026-09-07', 20, [9, 8, 8, 8]),
          ...session('2026-09-14', 20, [9, 8, 8, 7]),
          ...session('2026-09-21', 20, [8, 8, 8, 8]),
          ...session('2026-09-28', 20, [9, 8, 8, 8]),
        ],
      )!;
      expect(p.isStall, isTrue);
      expect(p.detail, contains('6.2 h'));
    });

    test('pull-ups: 4 × 10 strict → backpack load', () {
      final p = recommendProgression(
        exercise: 'Pull-ups',
        setsReps: '4 × max (stop 2 short of failure)',
        history: session('2026-09-28', 0, [10, 10, 10, 10], exercise: 'Pull-ups'),
      )!;
      expect(p.headline, 'Add +2 kg');
    });

    test('timed or unparseable targets give no advice rather than a guess', () {
      expect(
        recommendProgression(exercise: 'Plank', setsReps: '3 × 45–60s', history: session('2026-09-28', 0, [1], exercise: 'Plank')),
        isNull,
      );
    });
  });
}
