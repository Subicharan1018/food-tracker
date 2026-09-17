import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/dashboard/presentation/widgets/meal_slot_timing.dart';

void main() {
  test('focuses breakfast before 11:00', () {
    expect(mealSlotForTime(DateTime(2026, 9, 16, 10, 59)), 'breakfast');
  });

  test('focuses lunch from late morning through afternoon', () {
    expect(mealSlotForTime(DateTime(2026, 9, 16, 11, 0)), 'lunch');
    expect(mealSlotForTime(DateTime(2026, 9, 16, 13, 15)), 'lunch');
  });

  test('moves through shake, pre-workout, and dinner windows', () {
    expect(mealSlotForTime(DateTime(2026, 9, 16, 16, 0)), 'shake');
    expect(mealSlotForTime(DateTime(2026, 9, 16, 18, 0)), 'pre_workout');
    expect(mealSlotForTime(DateTime(2026, 9, 16, 20, 0)), 'dinner');
  });
}
