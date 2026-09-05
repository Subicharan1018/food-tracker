import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/adherence_engine/services/adherence_service.dart';

void main() {
  group('AdherenceEngine Tests', () {
    test('Returns none when progress is normal and progressing', () {
      final suggestion = AdherenceEngine.evaluate(
        weeklyAverages: [62.0, 62.6, 63.1],
        strengthStalledSessions: 0,
        reportedLowEnergy: false,
      );
      expect(suggestion.type, AdherenceSuggestionType.none);
    });

    test('Detects 3-week weight plateau and suggests trimming ~100-150 kcal', () {
      final suggestion = AdherenceEngine.evaluate(
        weeklyAverages: [62.0, 62.05, 62.1], // stagnant across 3 weeks
        strengthStalledSessions: 0,
        reportedLowEnergy: false,
      );
      expect(suggestion.type, AdherenceSuggestionType.trimCalories);
      expect(suggestion.recommendedDeltaKcal, -125);
      expect(suggestion.actionRecommendation, contains('Trim lunch rice portion'));
    });

    test('Detects strength stall and suggests adding ~150 kcal', () {
      final suggestion = AdherenceEngine.evaluate(
        weeklyAverages: [62.0, 62.0, 62.0],
        strengthStalledSessions: 2, // 2 sessions stalled
        reportedLowEnergy: false,
      );
      expect(suggestion.type, AdherenceSuggestionType.boostCalories);
      expect(suggestion.recommendedDeltaKcal, 150);
      expect(suggestion.actionRecommendation, contains('1 more chapati or a handful of peanuts'));
    });

    test('Detects low energy flag and prioritizes recovery boost', () {
      final suggestion = AdherenceEngine.evaluate(
        weeklyAverages: [62.0, 62.2, 62.5],
        strengthStalledSessions: 0,
        reportedLowEnergy: true,
      );
      expect(suggestion.type, AdherenceSuggestionType.boostCalories);
      expect(suggestion.recommendedDeltaKcal, 150);
    });
  });
}
