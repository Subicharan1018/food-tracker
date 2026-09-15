import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Notification IDs 200–206 reserved for workout start alarms.
const _workoutAlarms = [
  (id: 200, weekday: 1, hour: 17, minute: 45, title: "Upper A — Push Day",
   body: "Bench · OHP · Rows. Gym in 15 minutes.", day: "upper_a"),
  (id: 201, weekday: 2, hour: 17, minute: 45, title: "Lower A — Squat Day",
   body: "Barbell Squat · RDL · Lunges. 15 min.", day: "lower_a"),
  (id: 202, weekday: 3, hour: 17, minute: 45, title: "Zone 2 Conditioning",
   body: "30–35 min elliptical at conversational pace.", day: "zone2"),
  (id: 203, weekday: 4, hour: 17, minute: 45, title: "Upper B — Pull Day",
   body: "Pull-ups · Curls · Band work. You're ready.", day: "upper_b"),
  (id: 204, weekday: 5, hour: 17, minute: 45, title: "Lower B + HIIT",
   body: "Goblet Squats → Sumo DL → 6–8 sprint rounds.", day: "lower_b_hiit"),
  (id: 205, weekday: 6, hour: 8, minute: 0, title: "Active Recovery",
   body: "20–30 min walk + weekly grocery run.", day: "recovery"),
  (id: 206, weekday: 7, hour: 7, minute: 30, title: "Weigh-in Sunday",
   body: "Fasted, before water. Then batch meal prep.", day: "rest"),
];

class WorkoutNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  WorkoutNotificationService(this._plugin);

  /// Schedule all 7 recurring weekly alarms. Call once every Sunday.
  Future<void> scheduleWeeklyAlarms() async {
    final now = DateTime.now();
    for (final alarm in _workoutAlarms) {
      var scheduled = nextWeekday(now, alarm.weekday, alarm.hour, alarm.minute);
      await AndroidAlarmManager.oneShotAt(
        scheduled,
        alarm.id,
        _fireWorkoutNotification,
        exact: true,
        wakeup: true,
        alarmClock: true,
      );
    }
  }

  static DateTime nextWeekday(DateTime from, int weekday, int hour, int minute) {
    var d = DateTime(from.year, from.month, from.day, hour, minute);
    final daysUntil = (weekday - from.weekday + 7) % 7;
    d = d.add(Duration(days: daysUntil == 0 ? 7 : daysUntil));
    return d;
  }
}

@pragma('vm:entry-point')
Future<void> _fireWorkoutNotification() async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.show(
    200,
    'Workout Time',
    'Time for your scheduled workout session!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_start', 'Workout Start',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}
