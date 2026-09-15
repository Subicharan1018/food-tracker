import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../local_db/app_database.dart';

// Notification IDs 100–107 reserved for water reminders.
const _waterSlots = [
  (id: 100, hour: 7,  minute: 30, msg: "Start strong — 250 ml with breakfast."),
  (id: 101, hour: 9,  minute: 30, msg: "Mid-morning check. Keep sipping."),
  (id: 102, hour: 11, minute: 30, msg: "Pre-lunch — drink 250 ml before your 1 PM meal."),
  (id: 103, hour: 13, minute: 15, msg: "Post-lunch. Keep hydrating."),
  (id: 104, hour: 15, minute: 0,  msg: "Pre-whey shake time. Hydrate first."),
  (id: 105, hour: 17, minute: 0,  msg: "Pre-workout hydration. 300 ml before the gym."),
  (id: 106, hour: 19, minute: 0,  msg: "Post-workout. Replace sweat — 400 ml now."),
  (id: 107, hour: 21, minute: 0,  msg: "Finish strong. Check your remaining water target."),
];

class WaterNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final AppDatabase _db;

  WaterNotificationService(this._plugin, this._db);

  /// Call once at app start and every midnight.
  Future<void> scheduleAll() async {
    for (final slot in _waterSlots) {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, slot.hour, slot.minute);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await AndroidAlarmManager.oneShotAt(
        scheduled,
        slot.id,
        _fireWaterReminder,
        exact: true,
        wakeup: true,
        alarmClock: true,
      );
    }
  }

  /// Cancel all water reminders. Call when daily 3000 ml target is reached.
  Future<void> cancelAll() async {
    for (final slot in _waterSlots) {
      await AndroidAlarmManager.cancel(slot.id);
    }
  }

  /// Expected ml by a given hour using linear interpolation across 15 active hours.
  static double expectedMl(int hour) {
    if (hour <= 6) return 0.0;
    if (hour >= 21) return 3000.0;
    return ((hour - 6) / 15.0) * 3000.0;
  }
}

/// Top-level function required by android_alarm_manager_plus.
@pragma('vm:entry-point')
Future<void> _fireWaterReminder() async {
  final plugin = FlutterLocalNotificationsPlugin();
  final hour = DateTime.now().hour;
  await plugin.show(
    hour,
    'Hydration Check',
    'Time to drink water.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'water_reminders', 'Water Reminders',
        channelShowBadge: false,
      ),
    ),
  );
}
