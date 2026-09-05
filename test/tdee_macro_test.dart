import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/settings/services/tdee_calculator.dart';

void main() {
  group('TdeeCalculator Tests', () {
    test('Calculates accurate BMR for 62kg, 160cm, 21yo male', () {
      final bmr = TdeeCalculator.calculateBmr(
        weightKg: 62.0,
        heightCm: 160.0,
        age: 21,
        isMale: true,
      );
      // 10*62 + 6.25*160 - 5*21 + 5 = 620 + 1000 - 105 + 5 = 1520
      expect(bmr, 1520.0);
    });

    test('Calculates recomp macro profile close to target ~2350 kcal, ~155g protein', () {
      final profile = TdeeCalculator.computeRecompProfile(
        weightKg: 62.0,
        heightCm: 160.0,
        age: 21,
        activityLevel: 'moderate',
        manualCalories: 2350,
        manualProteinG: 155.0,
        manualFatG: 70.0,
        manualCarbG: 260.0,
      );

      expect(profile.calories, 2350);
      expect(profile.proteinG, 155.0);
      expect(profile.fatG, 70.0);
      expect(profile.carbG, 260.0);
      expect(profile.waterMl, 3000);
      expect(profile.stepsTarget, 10000);
    });
  });
}
