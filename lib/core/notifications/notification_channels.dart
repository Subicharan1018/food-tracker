import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationChannels {
  static const water = AndroidNotificationChannel(
    'water_reminders',
    'Water Reminders',
    description: 'Hourly hydration nudges',
    importance: Importance.defaultImportance,
    sound: RawResourceAndroidNotificationSound('drop'),
    enableVibration: true,
  );

  static const workout = AndroidNotificationChannel(
    'workout_start',
    'Workout Start',
    description: 'Scheduled gym session alarm',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('gym_bell'),
  );

  static const hiit = AndroidNotificationChannel(
    'hiit_timer',
    'HIIT Timer',
    description: 'Sprint and recovery interval cues',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('whistle_short'),
  );

  static const setRest = AndroidNotificationChannel(
    'set_rest_timer',
    'Set Rest Timer',
    description: 'Rest period between sets complete',
    importance: Importance.high,
    sound: RawResourceAndroidNotificationSound('ding'),
  );

  static Future<void> createAll(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(water);
    await android.createNotificationChannel(workout);
    await android.createNotificationChannel(hiit);
    await android.createNotificationChannel(setRest);
  }
}
