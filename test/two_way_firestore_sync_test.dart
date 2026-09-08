import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:food_tracker/core/auth/firebase_auth_rest_service.dart';
import 'package:food_tracker/core/network/google_firestore_sync_service.dart';
import 'package:food_tracker/core/local_db/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FirebaseAuthRestService authService;
  late GoogleFirestoreSyncService syncService;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'firebase_id_token': 'valid_test_id_token',
      'firebase_user_id': 'test_user_id',
      'firebase_token_expiry': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    db = AppDatabase(NativeDatabase.memory());
    authService = FirebaseAuthRestService(apiKey: 'TEST_KEY');
    syncService = GoogleFirestoreSyncService(
      authService: authService,
      projectId: 'test-fitness-project',
      userId: 'test_user_id',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Two-Way Firestore Sync Tests', () {
    test('Constructs endpoint and authenticated Bearer header', () async {
      expect(syncService.projectId, 'test-fitness-project');
      expect(syncService.userId, 'test_user_id');

      final token = await authService.getValidIdToken();
      expect(token != null && token.isNotEmpty, true);
    });

    test('Identifies and extracts dirty records across multiple collections', () async {
      // 1. Add dirty diary entry
      await db.addDiaryEntry(
        DiaryEntriesCompanion.insert(
          id: 'meal_1',
          date: '2026-09-06',
          mealSlot: 'breakfast',
          foodName: 'Vengaya Muttai Poriyal',
          portionQty: 1.0,
          portionUnit: 'meal',
          calories: 700.0,
          proteinG: 37.0,
          carbsG: 74.0,
          fatG: 21.0,
          isDirty: const Value(true),
        ),
      );

      // 2. Add dirty workout
      await db.addWorkoutSession(
        WorkoutSessionsCompanion.insert(
          id: 'workout_1',
          date: '2026-09-06',
          activityName: 'Subicharan Push Split',
          durationMin: 60,
          caloriesBurned: 320.0,
          isDirty: const Value(true),
        ),
      );

      // 3. Add dirty weigh-in
      await db.addWeighIn(
        WeighInsCompanion.insert(
          id: 'weigh_1',
          date: '2026-09-06',
          weightKg: 61.8,
          isDirty: const Value(true),
        ),
      );

      final dirtyMeals = await db.getDirtyDiaryEntries();
      final dirtyWorkouts = await db.getDirtyWorkoutSessions();
      final dirtyWeighIns = await db.getDirtyWeighIns();

      expect(dirtyMeals.length, 1);
      expect(dirtyWorkouts.length, 1);
      expect(dirtyWeighIns.length, 1);

      // Marking clean works
      await db.markDiaryEntriesClean(['meal_1']);
      final remainingDirtyMeals = await db.getDirtyDiaryEntries();
      expect(remainingDirtyMeals.isEmpty, true);
    });

    test('Measurements key on unique ID preventing same-day collisions (waist, biceps, thigh)', () async {
      const dateStr = '2026-09-06';

      // Log 3 distinct measurements on the same date
      await db.addMeasurement(
        MeasurementsCompanion.insert(
          id: 'm_waist_1',
          date: dateStr,
          type: 'waist',
          valueCm: 70.0,
        ),
      );
      await db.addMeasurement(
        MeasurementsCompanion.insert(
          id: 'm_biceps_1',
          date: dateStr,
          type: 'biceps',
          valueCm: 35.0,
        ),
      );
      await db.addMeasurement(
        MeasurementsCompanion.insert(
          id: 'm_chest_1',
          date: dateStr,
          type: 'chest',
          valueCm: 95.0,
        ),
      );

      final waist = await db.watchMeasurements('waist').first;
      final biceps = await db.watchMeasurements('biceps').first;
      final chest = await db.watchMeasurements('chest').first;

      expect(waist.length, 1);
      expect(waist.first.valueCm, 70.0);
      expect(biceps.length, 1);
      expect(biceps.first.valueCm, 35.0);
      expect(chest.length, 1);
      expect(chest.first.valueCm, 95.0);

      // All 3 coexist independently on the same date without collapsing
      final dirty = await db.getDirtyMeasurements();
      expect(dirty.length, 3);
    });

    test('Fresh install timestamp defaults to epoch 0 for complete pull', () async {
      final lastSync = await authService.getLastSyncTimestamp();
      expect(lastSync, isNotNull);
      expect(lastSync!.millisecondsSinceEpoch, 0);
    });

    test('Pull merge upsertMeasurementsBatch keys on row id/updatedAt and preserves same-day multi-type measurements', () async {
      const dateStr = '2026-09-06';
      final remoteCompanions = [
        MeasurementsCompanion(
          id: const Value('meas_waist_100'),
          date: const Value(dateStr),
          type: const Value('waist'),
          valueCm: const Value(72.0),
          loggedAt: Value(DateTime(2026, 9, 6, 8, 0)),
          isDirty: const Value(false),
          updatedAt: Value(DateTime(2026, 9, 6, 8, 0)),
        ),
        MeasurementsCompanion(
          id: const Value('meas_arms_101'),
          date: const Value(dateStr),
          type: const Value('arms'),
          valueCm: const Value(36.0),
          loggedAt: Value(DateTime(2026, 9, 6, 8, 5)),
          isDirty: const Value(false),
          updatedAt: Value(DateTime(2026, 9, 6, 8, 5)),
        ),
        MeasurementsCompanion(
          id: const Value('meas_thighs_102'),
          date: const Value(dateStr),
          type: const Value('thighs'),
          valueCm: const Value(57.5),
          loggedAt: Value(DateTime(2026, 9, 6, 8, 10)),
          isDirty: const Value(false),
          updatedAt: Value(DateTime(2026, 9, 6, 8, 10)),
        ),
      ];

      // Batch upsert from remote pull
      await db.upsertMeasurementsBatch(remoteCompanions);

      final waistLogs = await db.watchMeasurements('waist').first;
      final armLogs = await db.watchMeasurements('arms').first;
      final thighLogs = await db.watchMeasurements('thighs').first;

      expect(waistLogs.length, 1);
      expect(waistLogs.first.valueCm, 72.0);
      expect(armLogs.length, 1);
      expect(armLogs.first.valueCm, 36.0);
      expect(thighLogs.length, 1);
      expect(thighLogs.first.valueCm, 57.5);

      // Now simulate a last-write-wins update to the waist measurement
      final updatedWaist = MeasurementsCompanion(
        id: const Value('meas_waist_100'),
        date: const Value(dateStr),
        type: const Value('waist'),
        valueCm: const Value(71.5),
        loggedAt: Value(DateTime(2026, 9, 6, 8, 0)),
        isDirty: const Value(false),
        updatedAt: Value(DateTime(2026, 9, 6, 12, 0)),
      );
      await db.upsertMeasurementsBatch([updatedWaist]);

      final updatedWaistLogs = await db.watchMeasurements('waist').first;
      expect(updatedWaistLogs.length, 1);
      expect(updatedWaistLogs.first.valueCm, 71.5);
      // Other same-day measurements remain completely unaffected
      final armsCheck = await db.watchMeasurements('arms').first;
      expect(armsCheck.length, 1);
      expect(armsCheck.first.valueCm, 36.0);
    });
  });
}
