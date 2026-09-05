class MacroProfile {
  final int calories;
  final double proteinG;
  final double carbG;
  final double fatG;
  final double fiberG;
  final int waterMl;
  final int stepsTarget;

  const MacroProfile({
    required this.calories,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    this.fiberG = 30.0,
    this.waterMl = 3000,
    this.stepsTarget = 10000,
  });
}

class TdeeCalculator {
  /// Calculate Basal Metabolic Rate using Mifflin-St Jeor
  static double calculateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    bool isMale = true,
  }) {
    if (isMale) {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
  }

  /// Activity level multipliers
  static double getActivityMultiplier(String level) {
    switch (level.toLowerCase()) {
      case 'sedentary':
        return 1.2;
      case 'light':
        return 1.375;
      case 'moderate': // 4 days lifting + 3 conditioning (user's plan)
        return 1.55;
      case 'very_active':
        return 1.725;
      case 'extra_active':
        return 1.9;
      default:
        return 1.55;
    }
  }

  /// Compute Recomp Macro Profile
  static MacroProfile computeRecompProfile({
    required double weightKg,
    required double heightCm,
    required int age,
    String activityLevel = 'moderate',
    int? manualCalories,
    double? manualProteinG,
    double? manualFatG,
    double? manualCarbG,
  }) {
    final bmr = calculateBmr(weightKg: weightKg, heightCm: heightCm, age: age);
    final tdee = (bmr * getActivityMultiplier(activityLevel)).round();

    final targetCalories = manualCalories ?? tdee;

    // High protein target for recomp: ~2.2 - 2.5g / kg
    final targetProtein = manualProteinG ?? (weightKg * 2.5).clamp(140.0, 180.0);
    // Moderate healthy fats: ~1.0 - 1.1g / kg
    final targetFat = manualFatG ?? (weightKg * 1.1).clamp(60.0, 80.0);

    // Remaining calories for carbs
    final proteinKcal = targetProtein * 4;
    final fatKcal = targetFat * 9;
    final remainingKcal = (targetCalories - proteinKcal - fatKcal).clamp(100.0, 3000.0);
    final targetCarbs = manualCarbG ?? (remainingKcal / 4);

    return MacroProfile(
      calories: targetCalories,
      proteinG: (targetProtein * 10).round() / 10,
      carbG: (targetCarbs * 10).round() / 10,
      fatG: (targetFat * 10).round() / 10,
      fiberG: 30.0,
      waterMl: 3000,
      stepsTarget: 10000,
    );
  }
}
