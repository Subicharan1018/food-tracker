import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/sleep/presentation/screens/sleep_screen.dart';

void main() {
  group('SleepEngine Tests', () {
    test('Calculates sleep duration across midnight boundary (11:30 PM to 07:30 AM = 8h 0m)', () {
      final minutes = SleepEngine.computeSleepDurationMinutes(
        sleepHour: 23,
        sleepMinute: 30,
        wakeHour: 7,
        wakeMinute: 30,
      );

      expect(minutes, 480);
      expect(SleepEngine.formatDuration(minutes), '8h 0m');
    });

    test('Calculates same-day sleep duration without midnight boundary (1:00 AM to 08:30 AM = 7h 30m)', () {
      final minutes = SleepEngine.computeSleepDurationMinutes(
        sleepHour: 1,
        sleepMinute: 0,
        wakeHour: 8,
        wakeMinute: 30,
      );

      expect(minutes, 450);
      expect(SleepEngine.formatDuration(minutes), '7h 30m');
    });

    test('Calculates late night sleep (00:00 to 08:00 = 8h 0m)', () {
      final minutes = SleepEngine.computeSleepDurationMinutes(
        sleepHour: 0,
        sleepMinute: 0,
        wakeHour: 8,
        wakeMinute: 0,
      );

      expect(minutes, 480);
      expect(SleepEngine.formatDuration(minutes), '8h 0m');
    });
  });
}
