import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
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
  // How many servings the ingredient amounts make; one logged portion uses 1/servings.
  RealColumn get servings => real().withDefault(const Constant(1.0))();
  TextColumn get method => text()();
  TextColumn get shelfLifeTip => text().nullable()();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// 13. Inventory Items Table — the pantry the backend computes ceilings from.
// Synced to users/{uid}/inventory.
class InventoryItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get canonicalName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('pieces'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  // Tombstone: hidden locally, deleted remotely on next push, then purged.
  BoolColumn get pendingDelete => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 14. Shopping Cart Items Table — synced to users/{uid}/shopping_cart_items.
class ShoppingCartItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get canonicalName => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant('pieces'))();
  // addedFrom: "shopping_list" | "nutrient_gap" | "recipe_suggestion" | "manual"
  TextColumn get addedFrom => text()();
  // e.g. "Unlocks Naatu Kozhi Kuzhambu"
  TextColumn get reason => text().nullable()();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  BoolColumn get pendingDelete => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 15. Sleep Logs — one row per night, keyed by the local date you woke up.
// Imported from Health Connect; synced to users/{uid}/sleep_logs for the digest.
class SleepLogs extends Table {
  TextColumn get date => text()(); // YYYY-MM-DD of wake-up
  IntColumn get minutes => integer()();
  DateTimeColumn get bedtime => dateTime()();
  DateTimeColumn get wakeTime => dateTime()();
  TextColumn get source => text().withDefault(const Constant('health_connect'))();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {date};
}

// 16. Pantry usage — what logging a recipe took out of the pantry, so deleting
// that diary entry can put it back.  Amounts are in the pantry row's unit.
class PantryUsages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get diaryEntryId => text()();
  TextColumn get inventoryItemId => text()();
  TextColumn get name => text()();
  TextColumn get canonicalName => text()();
  RealColumn get amount => real()();
  TextColumn get unit => text()();
}

// 17. Remote deletes waiting to be pushed ("diary_entries/<id>").  Without
// this, a deleted row is pulled straight back on the next sync.
class SyncDeletions extends Table {
  TextColumn get path => text()();

  @override
  Set<Column> get primaryKey => {path};
}

// 18. Progress photos — files stay on the phone (private, large); never synced.
class ProgressPhotos extends Table {
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get path => text()();
  DateTimeColumn get takenAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {date};
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
  InventoryItems,
  ShoppingCartItems,
  SleepLogs,
  PantryUsages,
  SyncDeletions,
  ProgressPhotos,
])
class AppDatabase extends _$AppDatabase {
  SyncScheduler? syncScheduler;

  AppDatabase([QueryExecutor? e, this.syncScheduler]) : super(e ?? _openConnection());

  void attachSyncScheduler(SyncScheduler scheduler) {
    syncScheduler = scheduler;
  }

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(inventoryItems);
        await m.createTable(shoppingCartItems);
      } else if (from < 3) {
        // v2 used local autoincrement ids, which collide as Firestore doc ids
        // across devices.  Rebuild both tables with text ids, keeping rows.
        await m.alterTable(TableMigration(
          inventoryItems,
          columnTransformer: {inventoryItems.id: inventoryItems.id.cast<String>()},
          newColumns: [inventoryItems.pendingDelete],
        ));
        await m.alterTable(TableMigration(
          shoppingCartItems,
          columnTransformer: {shoppingCartItems.id: shoppingCartItems.id.cast<String>()},
          newColumns: [shoppingCartItems.updatedAt, shoppingCartItems.pendingDelete],
        ));
      }
      if (from < 4) {
        await m.createTable(sleepLogs);
      }
      if (from < 5) {
        await m.addColumn(recipes, recipes.servings);
        await m.createTable(pantryUsages);
        await m.createTable(syncDeletions);
      }
      if (from < 6) {
        await m.createTable(progressPhotos);
      }
    },
  );

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

  /// Deletes a meal everywhere: queues the remote delete and puts back any
  /// pantry stock that logging it had used.
  Future<bool> deleteDiaryEntry(String id) async {
    final deleted = await transaction(() async {
      final count = await (delete(diaryEntries)..where((e) => e.id.equals(id))).go();
      if (count == 0) return false;
      await into(syncDeletions).insertOnConflictUpdate(SyncDeletionsCompanion.insert(path: 'diary_entries/$id'));
      await _restorePantryUsage(id);
      return true;
    });
    if (deleted) syncScheduler?.scheduleSync();
    return deleted;
  }

  Future<void> _restorePantryUsage(String diaryEntryId) async {
    final usages = await (select(pantryUsages)..where((u) => u.diaryEntryId.equals(diaryEntryId))).get();
    for (final u in usages) {
      final row = await (select(inventoryItems)..where((i) => i.id.equals(u.inventoryItemId))).getSingleOrNull();
      if (row != null && !row.pendingDelete) {
        await incrementInventoryQuantity(row.id, u.amount);
      } else {
        await createInventoryItem(InventoryItemsCompanion.insert(
          name: u.name,
          canonicalName: u.canonicalName,
          quantity: Value(u.amount),
          unit: Value(u.unit),
        ));
      }
    }
    await (delete(pantryUsages)..where((u) => u.diaryEntryId.equals(diaryEntryId))).go();
  }

  Future<List<String>> getPendingDeletions() async =>
      (await select(syncDeletions).get()).map((d) => d.path).toList();

  Future<void> clearPendingDeletions(List<String> paths) =>
      (delete(syncDeletions)..where((d) => d.path.isIn(paths))).go();

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

  // ── Inventory Helpers ─────────────────────────────────────────────
  // Rows with pendingDelete are invisible to every reader below; only the
  // sync push sees them (to delete the remote doc) before they are purged.

  Future<List<InventoryItem>> getInventoryItemsByCanonicalName(String canonicalName) =>
      (select(inventoryItems)
            ..where((i) => i.canonicalName.equals(canonicalName) & i.pendingDelete.equals(false)))
          .get();

  Future<List<InventoryItem>> getAllInventoryItems() =>
      (select(inventoryItems)..where((i) => i.pendingDelete.equals(false))).get();

  Stream<List<InventoryItem>> watchInventoryItems() =>
      (select(inventoryItems)
            ..where((i) => i.pendingDelete.equals(false))
            ..orderBy([(i) => OrderingTerm.asc(i.name)]))
          .watch();

  Future<void> incrementInventoryQuantity(String id, double amount) async {
    await customUpdate(
      'UPDATE inventory_items SET quantity = quantity + ?, updated_at = ?, is_dirty = 1 WHERE id = ?',
      variables: [Variable.withReal(amount), Variable.withDateTime(DateTime.now()), Variable.withString(id)],
      updates: {inventoryItems},
    );
    syncScheduler?.scheduleSync();
  }

  Future<void> updateInventoryItem(String id, InventoryItemsCompanion companion) async {
    await (update(inventoryItems)..where((i) => i.id.equals(id))).write(
      companion.copyWith(updatedAt: Value(DateTime.now()), isDirty: const Value(true)),
    );
    syncScheduler?.scheduleSync();
  }

  Future<String> createInventoryItem(InventoryItemsCompanion item) async {
    final row = await into(inventoryItems).insertReturning(item);
    syncScheduler?.scheduleSync();
    return row.id;
  }

  Future<void> deleteInventoryItem(String id) async {
    await (update(inventoryItems)..where((i) => i.id.equals(id))).write(
      const InventoryItemsCompanion(pendingDelete: Value(true), isDirty: Value(true)),
    );
    syncScheduler?.scheduleSync();
  }

  Future<List<InventoryItem>> getDirtyInventoryItems() =>
      (select(inventoryItems)..where((i) => i.isDirty.equals(true))).get();

  Future<void> markInventoryItemsClean(List<String> ids) =>
      (update(inventoryItems)..where((i) => i.id.isIn(ids)))
          .write(const InventoryItemsCompanion(isDirty: Value(false)));

  Future<void> purgeInventoryItems(List<String> ids) =>
      (delete(inventoryItems)..where((i) => i.id.isIn(ids))).go();

  /// Applies a complete remote listing: upserts remote rows, drops clean local
  /// rows the remote no longer has, and never overwrites unpushed local edits.
  Future<void> reconcileInventory(List<InventoryItemsCompanion> remote) =>
      _reconcile(inventoryItems, remote, (c) => c.id.value);

  // ── Shopping Cart Helpers ─────────────────────────────────────────

  /// Unchecked live row for an ingredient — the dedup key for addToCart.
  Future<ShoppingCartItem?> getCartItemByCanonicalName(String canonicalName) =>
      (select(shoppingCartItems)
            ..where((c) =>
                c.canonicalName.equals(canonicalName) &
                c.checked.equals(false) &
                c.pendingDelete.equals(false))
            ..limit(1))
          .getSingleOrNull();

  Future<ShoppingCartItem?> getCartItem(String id) =>
      (select(shoppingCartItems)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<ShoppingCartItem>> getAllCartItems() =>
      (select(shoppingCartItems)..where((c) => c.pendingDelete.equals(false))).get();

  Stream<List<ShoppingCartItem>> watchCartItems() =>
      (select(shoppingCartItems)
            ..where((c) => c.pendingDelete.equals(false))
            ..orderBy([
              (c) => OrderingTerm.asc(c.checked),
              (c) => OrderingTerm.desc(c.addedAt),
            ]))
          .watch();

  Future<ShoppingCartItem> insertCartItem(ShoppingCartItemsCompanion item) =>
      into(shoppingCartItems).insertReturning(item);

  Future<void> updateCartItem(String id, ShoppingCartItemsCompanion companion) =>
      (update(shoppingCartItems)..where((c) => c.id.equals(id))).write(
        companion.copyWith(updatedAt: Value(DateTime.now()), isDirty: const Value(true)),
      );

  Future<void> deleteCartItem(String id) async {
    await updateCartItem(id, const ShoppingCartItemsCompanion(pendingDelete: Value(true)));
    syncScheduler?.scheduleSync();
  }

  Future<void> deleteCartItems(List<String> ids) async {
    await (update(shoppingCartItems)..where((c) => c.id.isIn(ids))).write(
      ShoppingCartItemsCompanion(
        pendingDelete: const Value(true),
        isDirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
    syncScheduler?.scheduleSync();
  }

  Future<void> deleteCheckedCartItems() async {
    final checked = await (select(shoppingCartItems)
          ..where((c) => c.checked.equals(true) & c.pendingDelete.equals(false)))
        .get();
    await deleteCartItems(checked.map((c) => c.id).toList());
  }

  Future<List<ShoppingCartItem>> getDirtyCartItems() =>
      (select(shoppingCartItems)..where((c) => c.isDirty.equals(true))).get();

  Future<void> markCartItemsClean(List<String> ids) =>
      (update(shoppingCartItems)..where((c) => c.id.isIn(ids)))
          .write(const ShoppingCartItemsCompanion(isDirty: Value(false)));

  Future<void> purgeCartItems(List<String> ids) =>
      (delete(shoppingCartItems)..where((c) => c.id.isIn(ids))).go();

  Future<void> reconcileCartItems(List<ShoppingCartItemsCompanion> remote) =>
      _reconcile(shoppingCartItems, remote, (c) => c.id.value);

  /// Most-logged food names per meal slot since [fromDate] (YYYY-MM-DD),
  /// most frequent first.  Drives the "usually" line on the home meal rail.
  Future<Map<String, List<String>>> usualFoodsBySlot(String fromDate, {int perSlot = 2}) async {
    final count = diaryEntries.id.count();
    final rows = await (selectOnly(diaryEntries)
          ..addColumns([diaryEntries.mealSlot, diaryEntries.foodName, count])
          ..where(diaryEntries.date.isBiggerOrEqualValue(fromDate))
          ..groupBy([diaryEntries.mealSlot, diaryEntries.foodName])
          ..orderBy([OrderingTerm.desc(count), OrderingTerm.asc(diaryEntries.foodName)]))
        .get();
    final result = <String, List<String>>{};
    for (final row in rows) {
      final list = result.putIfAbsent(row.read(diaryEntries.mealSlot)!, () => []);
      if (list.length < perSlot) list.add(row.read(diaryEntries.foodName)!);
    }
    return result;
  }

  /// For each meal slot, the entries from the most recent day before
  /// [beforeDate] (within [fromDate]) that slot was logged.
  Future<Map<String, List<DiaryEntry>>> lastMealsBySlot(String fromDate, String beforeDate) async {
    final rows = await (select(diaryEntries)
          ..where((e) => e.date.isBiggerOrEqualValue(fromDate) & e.date.isSmallerThanValue(beforeDate))
          ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.asc(e.loggedAt)]))
        .get();
    final latestDate = <String, String>{};
    final result = <String, List<DiaryEntry>>{};
    for (final row in rows) {
      final date = latestDate.putIfAbsent(row.mealSlot, () => row.date);
      if (row.date == date) result.putIfAbsent(row.mealSlot, () => []).add(row);
    }
    return result;
  }

  Stream<List<WorkoutSetLog>> watchSetLogsSince(String fromDate) =>
      (select(workoutSetLogs)..where((l) => l.date.isBiggerOrEqualValue(fromDate))).watch();

  Future<int> countSetsFor(String date, String exerciseName) async {
    final rows = await (select(workoutSetLogs)
          ..where((l) => l.date.equals(date) & l.exerciseName.equals(exerciseName)))
        .get();
    return rows.length;
  }

  /// Saves a weigh-in for [date] (replacing that day's) with a real rolling
  /// average: the mean of every weigh-in in the 7 days up to and including it.
  Future<void> saveWeighIn(String date, double weightKg) async {
    final day = DateTime.parse(date);
    final from = day.subtract(const Duration(days: 6)).toIso8601String().substring(0, 10);
    final window = await (select(weighIns)
          ..where((w) => w.date.isBiggerOrEqualValue(from) & w.date.isSmallerThanValue(date)))
        .get();
    final values = [...window.map((w) => w.weightKg), weightKg];
    final avg = values.reduce((a, b) => a + b) / values.length;
    final existing = await (select(weighIns)..where((w) => w.date.equals(date))).getSingleOrNull();
    await addWeighIn(WeighInsCompanion.insert(
      id: existing?.id ?? const Uuid().v4(),
      date: date,
      weightKg: weightKg,
      rollingAvgKg: Value(double.parse(avg.toStringAsFixed(2))),
      loggedAt: Value(DateTime.now()),
      isDirty: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // ── Check-in Helpers ──────────────────────────────────────────────

  Stream<List<ProgressPhoto>> watchProgressPhotos() =>
      (select(progressPhotos)..orderBy([(p) => OrderingTerm.asc(p.date)])).watch();

  Future<void> saveProgressPhoto(String date, String path) =>
      into(progressPhotos).insertOnConflictUpdate(ProgressPhotosCompanion.insert(date: date, path: path));

  Future<WeighIn?> latestWeighIn() =>
      (select(weighIns)..orderBy([(w) => OrderingTerm.desc(w.date)])..limit(1)).getSingleOrNull();

  Future<String?> latestMeasurementDate() async {
    final row = await (select(measurements)..orderBy([(m) => OrderingTerm.desc(m.date)])..limit(1)).getSingleOrNull();
    return row?.date;
  }

  // ── Sleep Helpers ─────────────────────────────────────────────────

  Stream<List<SleepLog>> watchRecentSleep(int nights) =>
      (select(sleepLogs)
            ..orderBy([(s) => OrderingTerm.desc(s.date)])
            ..limit(nights))
          .watch();

  /// Insert or update a night; only marks dirty when something changed, so
  /// re-importing the same Health Connect data doesn't re-push it.
  Future<bool> upsertSleepNight(String date, int minutes, DateTime bedtime, DateTime wakeTime) async {
    final existing = await (select(sleepLogs)..where((s) => s.date.equals(date))).getSingleOrNull();
    if (existing != null &&
        existing.minutes == minutes &&
        existing.bedtime == bedtime &&
        existing.wakeTime == wakeTime) {
      return false;
    }
    await into(sleepLogs).insertOnConflictUpdate(SleepLogsCompanion.insert(
      date: date,
      minutes: minutes,
      bedtime: bedtime,
      wakeTime: wakeTime,
      isDirty: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
    return true;
  }

  Future<List<SleepLog>> getDirtySleepLogs() =>
      (select(sleepLogs)..where((s) => s.isDirty.equals(true))).get();

  Future<void> markSleepLogsClean(List<String> dates) =>
      (update(sleepLogs)..where((s) => s.date.isIn(dates)))
          .write(const SleepLogsCompanion(isDirty: Value(false)));

  Future<void> _reconcile<T extends Table, D>(
    TableInfo<T, D> table,
    List<Insertable<D>> remote,
    String Function(dynamic companion) idOf,
  ) {
    return transaction(() async {
      final idColumn = table.columnsByName['id']! as GeneratedColumn<String>;
      final dirtyColumn = table.columnsByName['is_dirty']! as GeneratedColumn<bool>;
      final local = await (select(table)).get();
      final localDirty = <String>{};
      final localClean = <String>{};
      for (final row in local) {
        final json = (row as DataClass).toJson();
        (json['isDirty'] == true ? localDirty : localClean).add(json['id'] as String);
      }
      final remoteIds = <String>{};
      for (final companion in remote) {
        final id = idOf(companion);
        remoteIds.add(id);
        if (localDirty.contains(id)) continue; // local edit wins until pushed
        await into(table).insertOnConflictUpdate(companion);
      }
      final gone = localClean.difference(remoteIds);
      if (gone.isNotEmpty) {
        await (delete(table)..where((_) => idColumn.isIn(gone) & dirtyColumn.equals(false))).go();
      }
    });
  }
}
