import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'app_router.dart';
import 'core/di/providers.dart';
import 'core/notifications/notification_channels.dart';
import 'core/notifications/water_notification_service.dart';
import 'core/notifications/workout_notification_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep the device chrome in the same AMOLED-black canvas as the app.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.background,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarDividerColor: AppColors.background,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  ));

  final plugin = FlutterLocalNotificationsPlugin();
  try {
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          appRouter.push(payload);
        }
      },
    );
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await NotificationChannels.createAll(plugin);
  } catch (e) {
    debugPrint('Local notifications init fallback: $e');
  }

  try {
    await AndroidAlarmManager.initialize();
  } catch (e) {
    debugPrint('Alarm manager init fallback: $e');
  }

  runApp(
    const ProviderScope(
      child: KinetikFitnessApp(),
    ),
  );
}

class KinetikFitnessApp extends ConsumerStatefulWidget {
  const KinetikFitnessApp({super.key});

  @override
  ConsumerState<KinetikFitnessApp> createState() => _KinetikFitnessAppState();
}

class _KinetikFitnessAppState extends ConsumerState<KinetikFitnessApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Cold start auto-sync
      ref.read(syncSchedulerProvider).syncNow();

      // Schedule background water and workout notifications
      final db = ref.read(databaseProvider);
      final plugin = FlutterLocalNotificationsPlugin();
      try {
        await WaterNotificationService(plugin, db).scheduleAll();
        await WorkoutNotificationService(plugin).scheduleWeeklyAlarms();
      } catch (e) {
        debugPrint('Notification scheduling notice: $e');
      }

      // Register FCM token if authenticated
      try {
        final auth = ref.read(firebaseAuthRestServiceProvider);
        final userId = await auth.getUserId();
        if (userId != null && userId.isNotEmpty) {
          await auth.registerFcmToken(userId);
        }
      } catch (e) {
        debugPrint('FCM token registration notice: $e');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Foreground resume auto-sync
      ref.read(syncSchedulerProvider).syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kinetik — Recomp Manual & Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
