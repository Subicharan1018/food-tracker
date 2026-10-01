import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/health/health_sync_service.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/features/food_logging/presentation/screens/log_food_screen.dart';

FoodItem _food(String id, String name) => FoodItem(
      id: id,
      name: name,
      category: 'generic',
      servingSize: 100,
      servingUnit: 'g',
      calories: 100,
      proteinG: 1,
      carbsG: 1,
      fatG: 1,
      fiberG: 0,
      source: 'icmr_nin_2017',
      isGeneric: true,
      updatedAt: DateTime(2026),
    );

void main() {
  group('natural-language logging only uses a food it is sure of', () {
    test('substring hits that are a different food are rejected', () {
      final results = [_food('a', 'Brinjal, eggplant curry'), _food('b', 'Egg noodles')];
      expect(confidentFoodMatch(results, 'egg'), isNull);
    });

    test('exact canonical name wins, ignoring the regional suffix', () {
      final results = [_food('a', 'Spinach (Palak)'), _food('b', 'Spinach soup')];
      expect(confidentFoodMatch(results, 'palak')?.id, 'a');
    });

    test('ambiguous variants are not guessed', () {
      final results = [_food('a', 'Onion, big'), _food('b', 'Onion, small')];
      expect(confidentFoodMatch(results, 'onion'), isNull);
    });

    test('a single IFCT-style variant is accepted', () {
      final results = [_food('a', 'Drumstick, leaves'), _food('b', 'Chicken drumstick curry')];
      expect(confidentFoodMatch(results, 'drumstick')?.id, 'a');
    });
  });

  group('sleep nights from Health Connect sessions', () {
    test('a night split by a wake-up is summed and keyed by the wake date', () {
      final nights = groupSleepNights([
        (DateTime(2026, 9, 30, 23, 30), DateTime(2026, 10, 1, 3, 0)),
        (DateTime(2026, 10, 1, 3, 20), DateTime(2026, 10, 1, 7, 0)),
      ]);
      expect(nights.single.date, '2026-10-01');
      expect(nights.single.minutes, 210 + 220);
      expect(nights.single.bedtime, DateTime(2026, 9, 30, 23, 30));
      expect(nights.single.wakeTime, DateTime(2026, 10, 1, 7, 0));
    });

    test('overlapping sessions from two apps are not double counted', () {
      final nights = groupSleepNights([
        (DateTime(2026, 9, 30, 23, 0), DateTime(2026, 10, 1, 7, 0)),
        (DateTime(2026, 9, 30, 23, 15), DateTime(2026, 10, 1, 6, 45)),
      ]);
      expect(nights.single.minutes, 480);
    });

    test('re-importing an unchanged night does not mark it for sync again', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final bed = DateTime(2026, 9, 30, 23), wake = DateTime(2026, 10, 1, 7);
      expect(await db.upsertSleepNight('2026-10-01', 480, bed, wake), isTrue);
      await db.markSleepLogsClean(['2026-10-01']);
      expect(await db.upsertSleepNight('2026-10-01', 480, bed, wake), isFalse);
      expect(await db.getDirtySleepLogs(), isEmpty);
      await db.close();
    });
  });

  test('home meal rail "usually" line comes from what was actually logged', () async {
    final db = AppDatabase(NativeDatabase.memory());
    Future<void> log(String date, String slot, String food) => db.into(db.diaryEntries).insert(
          DiaryEntriesCompanion.insert(
            id: '$date-$slot-$food',
            date: date,
            mealSlot: slot,
            foodName: food,
            portionQty: 1,
            portionUnit: 'serving',
            calories: 100,
            proteinG: 1,
            carbsG: 1,
            fatG: 1,
          ),
        );
    await log('2026-09-28', 'breakfast', 'Chapati');
    await log('2026-09-29', 'breakfast', 'Chapati');
    await log('2026-09-29', 'breakfast', 'Egg bhurji');
    await log('2026-09-30', 'breakfast', 'Oats');
    await log('2026-09-01', 'breakfast', 'Dosa'); // older than the window
    final usual = await db.usualFoodsBySlot('2026-09-17');
    expect(usual['breakfast'], ['Chapati', 'Egg bhurji']);
    expect(usual.containsKey('dinner'), isFalse);
    await db.close();
  });
}
