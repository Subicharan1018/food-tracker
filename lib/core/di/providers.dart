import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../local_db/app_database.dart';
import '../local_db/seed_data.dart';

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
