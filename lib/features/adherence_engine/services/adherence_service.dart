enum AdherenceSuggestionType {
  none,
  trimCalories,
  boostCalories,
  maintain,
}

class AdherenceSuggestion {
  final AdherenceSuggestionType type;
  final String title;
  final String description;
  final String actionRecommendation;
  final int recommendedDeltaKcal;

  const AdherenceSuggestion({
    required this.type,
    required this.title,
    required this.description,
    required this.actionRecommendation,
    required this.recommendedDeltaKcal,
  });

  static const AdherenceSuggestion none = AdherenceSuggestion(
    type: AdherenceSuggestionType.none,
    title: "On Track",
    description: "Your progress is steady. Continue adhering to the recomp phase targets.",
    actionRecommendation: "Maintain current macros and training intensity.",
    recommendedDeltaKcal: 0,
  );
}

class AdherenceEngine {
  /// Evaluates weekly weight rolling averages and strength indicators.
  /// - [weeklyAverages]: List of rolling averages from newest to oldest (at least 3-4 weeks).
  /// - [strengthStalledSessions]: Number of consecutive sessions where top-of-range reps were not hit.
  /// - [reportedLowEnergy]: Whether the user logged low energy or fatigue.
  static AdherenceSuggestion evaluate({
    required List<double> weeklyAverages,
    int strengthStalledSessions = 0,
    bool reportedLowEnergy = false,
  }) {
    // Check for energy or strength stalls first
    if (strengthStalledSessions >= 2 || reportedLowEnergy) {
      return const AdherenceSuggestion(
        type: AdherenceSuggestionType.boostCalories,
        title: "Recovery & Strength Stall Detected",
        description:
            "Your strength has stalled across recent sessions or energy is flagged low. Your body needs slightly more fuel for recomp recovery.",
        actionRecommendation:
            "Add a small extra: 1 more chapati or a handful of peanuts (~150 kcal extra).",
        recommendedDeltaKcal: 150,
      );
    }

    // Check for 3-week weight plateau
    if (weeklyAverages.length >= 3) {
      final w0 = weeklyAverages[0]; // most recent
      final w1 = weeklyAverages[1]; // 1 week ago
      final w2 = weeklyAverages[2]; // 2 weeks ago

      final maxDiff = [
        (w0 - w1).abs(),
        (w1 - w2).abs(),
        (w0 - w2).abs(),
      ].reduce((curr, next) => curr > next ? curr : next);

      // Plateau threshold: within 0.2 kg across 3 full weeks
      if (maxDiff <= 0.25) {
        return const AdherenceSuggestion(
          type: AdherenceSuggestionType.trimCalories,
          title: "3-Week Weight Plateau Detected",
          description:
              "Weekly average weight hasn't moved for 3+ consecutive weeks. To stimulate body fat recomp without muscle loss, apply the plan's adjustment rule.",
          actionRecommendation:
              "Trim lunch rice portion by ~½ cup (~100–150 kcal deficit). Keep protein high at 155g.",
          recommendedDeltaKcal: -125,
        );
      }
    }

    return AdherenceSuggestion.none;
  }
}
