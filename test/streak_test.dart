import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/streaks/services/streak_service.dart';

void main() {
  group('StreakEngine Tests', () {
    final day1 = DateTime(2026, 9, 1);
    final day2 = DateTime(2026, 9, 2);
    final day3 = DateTime(2026, 9, 3);
    final day5 = DateTime(2026, 9, 5); // skipped day 4

    test('First activity starts streak at 1', () {
      final res = StreakEngine.processActivity(
        currentCount: 0,
        longestCount: 0,
        lastActiveDate: null,
        today: day1,
      );
      expect(res.currentCount, 1);
      expect(res.longestCount, 1);
      expect(res.lastActiveDate, '2026-09-01');
      expect(res.incremented, true);
    });

    test('Logging multiple times on same day does not re-increment', () {
      final res = StreakEngine.processActivity(
        currentCount: 1,
        longestCount: 1,
        lastActiveDate: '2026-09-01',
        today: day1,
      );
      expect(res.currentCount, 1);
      expect(res.incremented, false);
    });

    test('Logging on consecutive day increments streak', () {
      final res = StreakEngine.processActivity(
        currentCount: 1,
        longestCount: 1,
        lastActiveDate: '2026-09-01',
        today: day2,
      );
      expect(res.currentCount, 2);
      expect(res.longestCount, 2);
      expect(res.lastActiveDate, '2026-09-02');
      expect(res.incremented, true);

      final res3 = StreakEngine.processActivity(
        currentCount: 2,
        longestCount: 2,
        lastActiveDate: '2026-09-02',
        today: day3,
      );
      expect(res3.currentCount, 3);
      expect(res3.longestCount, 3);
    });

    test('Skipping a day resets streak to 1 while preserving longestCount', () {
      final res = StreakEngine.processActivity(
        currentCount: 3,
        longestCount: 3,
        lastActiveDate: '2026-09-03',
        today: day5, // skipped Sep 4
      );
      expect(res.currentCount, 1);
      expect(res.longestCount, 3); // preserved!
      expect(res.lastActiveDate, '2026-09-05');
      expect(res.incremented, true);
    });
  });
}
