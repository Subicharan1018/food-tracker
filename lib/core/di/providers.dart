import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth/firebase_auth_rest_service.dart';
import '../config/firebase_config.dart';
import '../health/health_sync_service.dart';
import '../local_db/app_database.dart';
import '../local_db/seed_data.dart';
import '../network/google_firestore_sync_service.dart';

import '../sync/sync_scheduler.dart';

// Services
final healthSyncServiceProvider = Provider<HealthSyncService>((ref) {
  final service = HealthSyncService();
  service.initialize();
  return service;
});

final firebaseAuthRestServiceProvider = Provider<FirebaseAuthRestService>((ref) {
  return FirebaseAuthRestService(apiKey: FirebaseConfig.apiKey);
});

final firestoreSyncServiceProvider = Provider<GoogleFirestoreSyncService>((ref) {
  final auth = ref.watch(firebaseAuthRestServiceProvider);
  return GoogleFirestoreSyncService(
    authService: auth,
    projectId: FirebaseConfig.projectId,
    apiKey: FirebaseConfig.apiKey,
  );
});

// Single Sync Scheduler Provider
final syncSchedulerProvider = ChangeNotifierProvider<SyncScheduler>((ref) {
  final syncService = ref.watch(firestoreSyncServiceProvider);
  final auth = ref.watch(firebaseAuthRestServiceProvider);
  final db = ref.watch(databaseProvider);
  final scheduler = SyncScheduler(
    syncService: syncService,
    authService: auth,
    db: db,
  );
  db.attachSyncScheduler(scheduler);
  return scheduler;
});

// Live Sync Status Provider
final syncStatusProvider = Provider<SyncSchedulerStatus>((ref) {
  final scheduler = ref.watch(syncSchedulerProvider);
  return scheduler.status;
});

// Backward-compatible SyncState provider
class SyncState {
  final bool isSyncing;
  final SyncResult? lastResult;
  final String? error;

  const SyncState({this.isSyncing = false, this.lastResult, this.error});
}

final syncStatusNotifierProvider = StateNotifierProvider<SyncStatusNotifier, SyncState>((ref) {
  final scheduler = ref.watch(syncSchedulerProvider);
  return SyncStatusNotifier(scheduler);
});

class SyncStatusNotifier extends StateNotifier<SyncState> {
  final SyncScheduler _scheduler;

  SyncStatusNotifier(this._scheduler)
      : super(SyncState(
          isSyncing: _scheduler.status.isSyncing,
          lastResult: _scheduler.status.lastResult,
          error: _scheduler.status.error,
        ));

  Future<SyncResult?> triggerSync() async {
    state = const SyncState(isSyncing: true);
    final res = await _scheduler.syncNow();
    state = SyncState(
      isSyncing: false,
      lastResult: res,
      error: res != null && !res.success ? res.errorMessage : null,
    );
    return res;
  }
}

// Database Singleton Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Ensure seed data is initialized
  SeedData.seedInitialData(db);
  ref.onDispose(() => db.close());
  return db;
});


// Current Selected Date (default: today)
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Formatted Date String helper: YYYY-MM-DD
final formattedSelectedDateProvider = Provider<String>((ref) {
  final date = ref.watch(selectedDateProvider);
  return DateFormat('yyyy-MM-dd').format(date);
});

// User Profile Stream
final userProfileProvider = StreamProvider<User?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.users).watchSingleOrNull();
});

// Diary Entries for Selected Date
final diaryEntriesProvider = StreamProvider<List<DiaryEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  final dateStr = ref.watch(formattedSelectedDateProvider);
  return db.watchEntriesForDate(dateStr);
});

// Water Logs for Selected Date
final dailyWaterProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  final dateStr = ref.watch(formattedSelectedDateProvider);
  return db.watchWaterForDate(dateStr);
});

// Workouts for Selected Date
final dailyWorkoutsProvider = StreamProvider<List<WorkoutSession>>((ref) {
  final db = ref.watch(databaseProvider);
  final dateStr = ref.watch(formattedSelectedDateProvider);
  return db.watchWorkoutsForDate(dateStr);
});

// Strength Set Logs for Selected Date
final dailySetLogsProvider = StreamProvider<List<WorkoutSetLog>>((ref) {
  final db = ref.watch(databaseProvider);
  final dateStr = ref.watch(formattedSelectedDateProvider);
  return db.watchSetLogsForDate(dateStr);
});

// Recent Foods
final recentFoodsProvider = FutureProvider<List<String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getRecentFoodNames(10);
});

// Recipes Stream
final recipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecipes();
});

// Weigh-Ins Stream
final weighInsStreamProvider = StreamProvider<List<WeighIn>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchWeighIns(30);
});

// Logging Streak Provider
final loggingStreakProvider = FutureProvider<Streak?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getStreak('logging');
});

// Workout Streak Provider
final workoutStreakProvider = FutureProvider<Streak?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.getStreak('workout');
});

const defaultDailyStepsTarget = 10000;

// Today Steps Provider (from Health Connect / Local sync)
final todayStepsProvider = FutureProvider<int>((ref) async {
  final health = ref.watch(healthSyncServiceProvider);
  return health.fetchTodaySteps();
});
