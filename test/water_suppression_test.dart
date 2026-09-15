import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/notifications/water_notification_service.dart';

void main() {
  group('WaterNotificationService Expected Hydration Curve', () {
    test('expectedMl at or before 6 AM is 0 ml', () {
      expect(WaterNotificationService.expectedMl(5), 0.0);
      expect(WaterNotificationService.expectedMl(6), 0.0);
    });

    test('expectedMl at or after 21:00 (9 PM) is full 3000 ml target', () {
      expect(WaterNotificationService.expectedMl(21), 3000.0);
      expect(WaterNotificationService.expectedMl(23), 3000.0);
    });

    test('expectedMl linear progression throughout active day', () {
      // Hour 11 (5 hours active): (5/15) * 3000 = 1000 ml
      expect(WaterNotificationService.expectedMl(11), 1000.0);

      // Hour 16 (10 hours active): (10/15) * 3000 = 2000 ml
      expect(WaterNotificationService.expectedMl(16), 2000.0);

      // Midday Hour 13.5: ((13.5-6)/15) * 3000 = 1500 ml
      expect(WaterNotificationService.expectedMl(13), closeTo(1400.0, 1.0));
    });
  });
}
