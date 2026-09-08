import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../sync/sync_scheduler.dart';

part 'app_database.g.dart';

// 1. Users Table
class Users extends Table {
  TextColumn get id => text().withDefault(const Constant('default_user'))();
  RealColumn get heightCm => real().withDefault(const Constant(160.0))();
  RealColumn get weightKg => real().withDefault(const Constant(62.0))();
  IntColumn get age => integer().withDefault(const Constant(21))();
  TextColumn get activityLevel => text().withDefault(const Constant('moderate'))();
  IntColumn get calorieTarget => integer().withDefault(const Constant(2350))();
  RealColumn get proteinTargetG => real().withDefault(const Constant(155.0))();
  RealColumn get carbTargetG => real().withDefault(const Constant(260.0))();
  RealColumn get fatTargetG => real().withDefault(const Constant(70.0))();
  RealColumn get fiberTargetG => real().withDefault(const Constant(30.0))();
  IntColumn get waterTargetMl => integer().withDefault(const Constant(3000))();
  IntColumn get stepsTarget => integer().withDefault(const Constant(10000))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 2. Food Items Table
class FoodItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get brand => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('generic'))();
  RealColumn get servingSize => real().withDefault(const Constant(100.0))();
  TextColumn get servingUnit => text().withDefault(const Constant('g'))();
  RealColumn get calories => real()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fiberG => real().withDefault(const Constant(0.0))();
  TextColumn get source => text().withDefault(const Constant('icmr_nin'))();
  BoolColumn get isGeneric => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Custom Foods Table
class CustomFoods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get servingSize => real().withDefault(const Constant(100.0))();
  TextColumn get servingUnit => text().withDefault(const Constant('g'))();
  RealColumn get calories => real()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fiberG => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Diary Entries Table
class DiaryEntries extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get mealSlot => text()(); // breakfast, lunch, shake, pre_workout, dinner, snack
  TextColumn get foodItemId => text().nullable()();
  TextColumn get customFoodId => text().nullable()();
  TextColumn get foodName => text()();
  RealColumn get portionQty => real()(); // e.g., 1.0 or gram weight
  TextColumn get portionUnit => text()();
  RealColumn get calories => real()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fiberG => real().withDefault(const Constant(0.0))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 5. Activities Table
class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text().withDefault(const Constant('cardio'))();
  RealColumn get metValue => real()();
  IntColumn get defaultDurationMin => integer().withDefault(const Constant(30))();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 6. Workout Sessions Table
class WorkoutSessions extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get activityId => text().nullable()();
  TextColumn get activityName => text()();
  IntColumn get durationMin => integer()();
  TextColumn get intensity => text().withDefault(const Constant('moderate'))();
  RealColumn get caloriesBurned => real()();
  TextColumn get source => text().withDefault(const Constant('manual'))(); // manual, routine, health_connect
  TextColumn get notes => text().nullable()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 7. Workout Set Logs Table (Strength Training)
class WorkoutSetLogs extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get date => text()();
  TextColumn get exerciseName => text()();
  IntColumn get setIndex => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  TextColumn get targetReps => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// 8. Weigh-Ins Table
class WeighIns extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  RealColumn get weightKg => real()();
  RealColumn get rollingAvgKg => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 9. Measurements Table
class Measurements extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get type => text()(); // biceps, forearm, waist, chest, thigh
  RealColumn get valueCm => real()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 10. Water Logs Table
class WaterLogs extends Table {
  TextColumn get id => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  IntColumn get mlAdded => integer()();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// 11. Streaks Table
class Streaks extends Table {
  TextColumn get type => text()(); // 'logging', 'workout'
  IntColumn get currentCount => integer().withDefault(const Constant(0))();
  IntColumn get longestCount => integer().withDefault(const Constant(0))();
  TextColumn get lastActiveDate => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {type};
}

// 12. Recipes Table
class Recipes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get tamilName => text().nullable()();
  TextColumn get mealSlot => text()(); // breakfast, lunch, dinner, snack
  TextColumn get dayOfWeek => text().nullable()(); // Mon, Tue, etc.
  RealColumn get calories => real()();
  RealColumn get proteinG => real()();
  RealColumn get carbsG => real()();
  RealColumn get fatG => real()();
  RealColumn get fiberG => real().withDefault(const Constant(0.0))();
  TextColumn get ingredientsJson => text()();
  TextColumn get method => text()();
  TextColumn get shelfLifeTip => text().nullable()();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  Users,
  FoodItems,
  CustomFoods,
  DiaryEntries,
  Activities,
  WorkoutSessions,
  WorkoutSetLogs,
  WeighIns,
  Measurements,
  WaterLogs,
  Streaks,
  Recipes,
])
class AppDatabase extends _$AppDatabase {
  SyncScheduler? syncScheduler;

  AppDatabase([QueryExecutor? e, this.syncScheduler]) : super(e ?? _openConnection());

  void attachSyncScheduler(SyncScheduler scheduler) {
    syncScheduler = scheduler;
  }

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'food_tracker_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // --- Helper Query Methods ---

  // User Profile
  Future<User?> getUserProfile() =>
      (select(users)..where((u) => u.id.equals('default_user'))).getSingleOrNull();

  Future<void> saveUserProfile(UsersCompanion companion) async {
    await into(users).insertOnConflictUpdate(companion);
    syncScheduler?.scheduleSync();
  }

  // Food Items
  Future<List<FoodItem>> searchFoodItems(String query) {
    final lower = '%${query.toLowerCase()}%';
    return (select(foodItems)
          ..where((f) => f.name.lower().like(lower))
          ..limit(30))
        .get();
  }

  Future<void> insertFoodItemsBatch(List<FoodItemsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(foodItems, items);
    });
  }

  // Diary Entries
  Stream<List<DiaryEntry>> watchEntriesForDate(String dateStr) {
    return (select(diaryEntries)
          ..where((e) => e.date.equals(dateStr))
          ..orderBy([(e) => OrderingTerm.asc(e.loggedAt)]))
        .watch();
  }

  Future<List<DiaryEntry>> getEntriesForDate(String dateStr) {
    return (select(diaryEntries)
          ..where((e) => e.date.equals(dateStr))
          ..orderBy([(e) => OrderingTerm.asc(e.loggedAt)]))
        .get();
  }

  Future<int> addDiaryEntry(DiaryEntriesCompanion entry) async {
    final res = await into(diaryEntries).insert(entry);
    syncScheduler?.scheduleSync();
    return res;
  }

  Future<bool> deleteDiaryEntry(String id) async {
    final count = await (delete(diaryEntries)..where((e) => e.id.equals(id))).go();
    if (count > 0) {
      syncScheduler?.scheduleSync();
    }
    return count > 0;
  }

  // Frequent & Recent foods
  Future<List<String>> getRecentFoodNames(int limit) async {
    final entries = await (select(diaryEntries)
          ..orderBy([(e) => OrderingTerm.desc(e.loggedAt)])
          ..limit(limit))
        .get();
    return entries.map((e) => e.foodName).toSet().toList();
  }

  // Water Logs
  Stream<int> watchWaterForDate(String dateStr) {
    return (select(waterLogs)..where((w) => w.date.equals(dateStr)))
        .watch()
        .map((logs) => logs.fold<int>(0, (sum, l) => sum + l.mlAdded));
  }

  Future<void> addWaterLog(WaterLogsCompanion log) async {
    await into(waterLogs).insert(log);
    syncScheduler?.scheduleSync();
  }

  // Activities & Workouts
  Future<List<Activity>> searchActivities(String query) {
    final lower = '%${query.toLowerCase()}%';
    return (select(activities)
          ..where((a) => a.name.lower().like(lower))
          ..limit(30))
        .get();
  }

  Future<void> insertActivitiesBatch(List<ActivitiesCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(activities, items);
    });
  }

  Stream<List<WorkoutSession>> watchWorkoutsForDate(String dateStr) {
    return (select(workoutSessions)
          ..where((w) => w.date.equals(dateStr))
          ..orderBy([(w) => OrderingTerm.desc(w.loggedAt)]))
        .watch();
  }

  Future<void> addWorkoutSession(WorkoutSessionsCompanion session) async {
    await into(workoutSessions).insert(session);
    syncScheduler?.scheduleSync();
  }

  Future<void> addWorkoutSetLogs(List<WorkoutSetLogsCompanion> sets) async {
    await batch((b) {
      b.insertAll(workoutSetLogs, sets);
    });
    syncScheduler?.scheduleSync();
  }

  Stream<List<WorkoutSetLog>> watchSetLogsForDate(String dateStr) {
    return (select(workoutSetLogs)
          ..where((s) => s.date.equals(dateStr))
          ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
        .watch();
  }

  // Weigh-ins & Measurements
  Stream<List<WeighIn>> watchWeighIns(int limit) {
    return (select(weighIns)
          ..orderBy([(w) => OrderingTerm.desc(w.date)])
          ..limit(limit))
        .watch();
  }

  Future<void> addWeighIn(WeighInsCompanion weighIn) async {
    await into(weighIns).insertOnConflictUpdate(weighIn);
    syncScheduler?.scheduleSync();
  }

  Stream<List<Measurement>> watchMeasurements(String type) {
    return (select(measurements)
          ..where((m) => m.type.equals(type))
          ..orderBy([(m) => OrderingTerm.desc(m.date)]))
        .watch();
  }

  Future<void> addMeasurement(MeasurementsCompanion measurement) async {
    await into(measurements).insertOnConflictUpdate(measurement);
    syncScheduler?.scheduleSync();
  }

  // Recipes
  Stream<List<Recipe>> watchRecipes() => select(recipes).watch();
  Future<List<Recipe>> getAllRecipes() => select(recipes).get();

  Future<void> insertRecipesBatch(List<RecipesCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(recipes, items);
    });
    syncScheduler?.scheduleSync();
  }

  // Streaks
  Future<Streak?> getStreak(String type) =>
      (select(streaks)..where((s) => s.type.equals(type))).getSingleOrNull();

  Future<void> updateStreak(StreaksCompanion streak) =>
      into(streaks).insertOnConflictUpdate(streak);

  // --- Two-Way Firestore Sync Query Helpers ---

  // Dirty record extractors
  Future<List<DiaryEntry>> getDirtyDiaryEntries() =>
      (select(diaryEntries)..where((d) => d.isDirty.equals(true))).get();

  Future<void> markDiaryEntriesClean(List<String> ids) =>
      (update(diaryEntries)..where((d) => d.id.isIn(ids)))
          .write(const DiaryEntriesCompanion(isDirty: Value(false)));

  Future<List<WorkoutSession>> getDirtyWorkoutSessions() =>
      (select(workoutSessions)..where((w) => w.isDirty.equals(true))).get();

  Future<void> markWorkoutSessionsClean(List<String> ids) =>
      (update(workoutSessions)..where((w) => w.id.isIn(ids)))
          .write(const WorkoutSessionsCompanion(isDirty: Value(false)));

  Future<List<WorkoutSetLog>> getDirtyWorkoutSetLogs() =>
      (select(workoutSetLogs)..where((w) => w.isDirty.equals(true))).get();

  Future<void> markWorkoutSetLogsClean(List<String> ids) =>
      (update(workoutSetLogs)..where((w) => w.id.isIn(ids)))
          .write(const WorkoutSetLogsCompanion(isDirty: Value(false)));

  Future<List<WeighIn>> getDirtyWeighIns() =>
      (select(weighIns)..where((w) => w.isDirty.equals(true))).get();

  Future<void> markWeighInsClean(List<String> ids) =>
      (update(weighIns)..where((w) => w.id.isIn(ids)))
          .write(const WeighInsCompanion(isDirty: Value(false)));

  Future<List<Measurement>> getDirtyMeasurements() =>
      (select(measurements)..where((m) => m.isDirty.equals(true))).get();

  Future<void> markMeasurementsClean(List<String> ids) =>
      (update(measurements)..where((m) => m.id.isIn(ids)))
          .write(const MeasurementsCompanion(isDirty: Value(false)));

  Future<List<WaterLog>> getDirtyWaterLogs() =>
      (select(waterLogs)..where((w) => w.isDirty.equals(true))).get();

  Future<void> markWaterLogsClean(List<String> ids) =>
      (update(waterLogs)..where((w) => w.id.isIn(ids)))
          .write(const WaterLogsCompanion(isDirty: Value(false)));

  Future<List<CustomFood>> getDirtyCustomFoods() =>
      (select(customFoods)..where((c) => c.isDirty.equals(true))).get();

  Future<void> markCustomFoodsClean(List<String> ids) =>
      (update(customFoods)..where((c) => c.id.isIn(ids)))
          .write(const CustomFoodsCompanion(isDirty: Value(false)));

  // Batch Upsert Helpers for Pull Sync
  Future<void> upsertDiaryEntriesBatch(List<DiaryEntriesCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(diaryEntries, entries);
    });
  }

  Future<void> upsertWorkoutsBatch(List<WorkoutSessionsCompanion> sessions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(workoutSessions, sessions);
    });
  }

  Future<void> upsertWorkoutSetLogsBatch(List<WorkoutSetLogsCompanion> sets) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(workoutSetLogs, sets);
    });
  }

  Future<void> upsertWeighInsBatch(List<WeighInsCompanion> records) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(weighIns, records);
    });
  }

  Future<void> upsertMeasurementsBatch(List<MeasurementsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(measurements, items);
    });
  }

  Future<void> upsertWaterLogsBatch(List<WaterLogsCompanion> logs) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(waterLogs, logs);
    });
  }

  Future<void> upsertCustomFoodsBatch(List<CustomFoodsCompanion> foods) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(customFoods, foods);
    });
  }
}

