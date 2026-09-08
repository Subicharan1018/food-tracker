import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../auth/firebase_auth_rest_service.dart';
import '../local_db/app_database.dart';

class SyncResult {
  final int pushedCount;
  final int pulledCount;
  final bool success;
  final String? errorMessage;
  final DateTime timestamp;

  const SyncResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.success,
    this.errorMessage,
    required this.timestamp,
  });
}

class GoogleFirestoreSyncService {
  final Dio _dio;
  final FirebaseAuthRestService _authService;
  String projectId;
  String userId;
  String? apiKey;

  GoogleFirestoreSyncService({
    Dio? dio,
    FirebaseAuthRestService? authService,
    this.projectId = 'food-tracker-b8a23',
    this.userId = 'default_user',
    this.apiKey,
  })  : _dio = dio ?? Dio(),
        _authService = authService ?? FirebaseAuthRestService();

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  Future<Map<String, String>?> _getAuthHeaders() async {
    final token = await _authService.getValidIdToken();
    if (token == null || token.isEmpty) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Test connection to Google Cloud Firestore project with authentication
  Future<bool> testConnection() async {
    try {
      final authState = await _authService.getAuthState();
      if (authState is AuthFailure) {
        debugPrint('Firestore test connection aborted: ${authState.message}');
        return false;
      }
      userId = (authState as AuthSuccess).userId;
      final headers = await _getAuthHeaders();
      if (headers == null) return false;

      final url = '$_baseUrl/users/$userId';
      final response = await _dio.get(
        url,
        queryParameters: apiKey != null ? {'key': apiKey} : null,
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      debugPrint('Firestore test connection error: $e');
      return false;
    }
  }

  /// Full Two-Way Sync: Pushes all local dirty rows, pulls remote updates via scoped queries
  Future<SyncResult> syncAll(AppDatabase db) async {
    int totalPushed = 0;
    int totalPulled = 0;

    try {
      final authState = await _authService.getAuthState();
      if (authState is AuthFailure) {
        return SyncResult(
          pushedCount: 0,
          pulledCount: 0,
          success: false,
          errorMessage: authState.message,
          timestamp: DateTime.now(),
        );
      }

      userId = (authState as AuthSuccess).userId;

      // 1. PUSH local dirty records across all subcollections
      totalPushed = await syncDirtyRecords(db);

      // 2. PULL remote updates across all subcollections
      totalPulled = await pullRemoteChanges(db);

      // 3. Update sync timestamp upon success
      final now = DateTime.now();
      await _authService.updateLastSyncTimestamp(now);

      return SyncResult(
        pushedCount: totalPushed,
        pulledCount: totalPulled,
        success: true,
        timestamp: now,
      );
    } catch (e) {
      debugPrint('Sync failed: $e');
      return SyncResult(
        pushedCount: totalPushed,
        pulledCount: totalPulled,
        success: false,
        errorMessage: e.toString(),
        timestamp: DateTime.now(),
      );
    }
  }

  /// Pushes all records across all 8 user subcollections + profile marked isDirty == true
  Future<int> syncDirtyRecords(AppDatabase db) async {
    int count = 0;
    final headers = await _getAuthHeaders();
    if (headers == null) return 0;

    // 1. Diary Entries
    final dirtyEntries = await db.getDirtyDiaryEntries();
    final syncedEntryIds = <String>[];
    for (final entry in dirtyEntries) {
      final docUrl = '$_baseUrl/users/$userId/diary_entries/${entry.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": entry.id},
          "date": {"stringValue": entry.date},
          "mealSlot": {"stringValue": entry.mealSlot},
          "foodName": {"stringValue": entry.foodName},
          "portionQty": {"doubleValue": entry.portionQty},
          "portionUnit": {"stringValue": entry.portionUnit},
          "calories": {"doubleValue": entry.calories},
          "proteinG": {"doubleValue": entry.proteinG},
          "carbsG": {"doubleValue": entry.carbsG},
          "fatG": {"doubleValue": entry.fatG},
          "fiberG": {"doubleValue": entry.fiberG},
          "loggedAt": {"stringValue": entry.loggedAt.toIso8601String()},
          "updatedAt": {"stringValue": entry.updatedAt.toIso8601String()},
        }
      };

      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedEntryIds.add(entry.id);
    }
    if (syncedEntryIds.isNotEmpty) {
      await db.markDiaryEntriesClean(syncedEntryIds);
      count += syncedEntryIds.length;
    }

    // 2. Workout Sessions
    final dirtyWorkouts = await db.getDirtyWorkoutSessions();
    final syncedWorkoutIds = <String>[];
    for (final w in dirtyWorkouts) {
      final docUrl = '$_baseUrl/users/$userId/workout_sessions/${w.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": w.id},
          "date": {"stringValue": w.date},
          "activityName": {"stringValue": w.activityName},
          "durationMin": {"integerValue": w.durationMin.toString()},
          "intensity": {"stringValue": w.intensity},
          "caloriesBurned": {"doubleValue": w.caloriesBurned},
          "source": {"stringValue": w.source},
          "loggedAt": {"stringValue": w.loggedAt.toIso8601String()},
          "updatedAt": {"stringValue": w.updatedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedWorkoutIds.add(w.id);
    }
    if (syncedWorkoutIds.isNotEmpty) {
      await db.markWorkoutSessionsClean(syncedWorkoutIds);
      count += syncedWorkoutIds.length;
    }

    // 3. Workout Set Logs
    final dirtySetLogs = await db.getDirtyWorkoutSetLogs();
    final syncedSetLogIds = <String>[];
    for (final s in dirtySetLogs) {
      final docUrl = '$_baseUrl/users/$userId/workout_set_logs/${s.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": s.id},
          "sessionId": {"stringValue": s.sessionId},
          "date": {"stringValue": s.date},
          "exerciseName": {"stringValue": s.exerciseName},
          "setIndex": {"integerValue": s.setIndex.toString()},
          "weightKg": {"doubleValue": s.weightKg},
          "reps": {"integerValue": s.reps.toString()},
          "targetReps": {"stringValue": s.targetReps ?? ''},
          "completed": {"booleanValue": s.completed},
          "loggedAt": {"stringValue": s.loggedAt.toIso8601String()},
          "updatedAt": {"stringValue": s.loggedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedSetLogIds.add(s.id);
    }
    if (syncedSetLogIds.isNotEmpty) {
      await db.markWorkoutSetLogsClean(syncedSetLogIds);
      count += syncedSetLogIds.length;
    }

    // 4. Weigh-Ins
    final dirtyWeighIns = await db.getDirtyWeighIns();
    final syncedWeighInIds = <String>[];
    for (final win in dirtyWeighIns) {
      final docUrl = '$_baseUrl/users/$userId/weigh_ins/${win.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": win.id},
          "date": {"stringValue": win.date},
          "weightKg": {"doubleValue": win.weightKg},
          "rollingAvgKg": {"doubleValue": win.rollingAvgKg ?? win.weightKg},
          "loggedAt": {"stringValue": win.loggedAt.toIso8601String()},
          "updatedAt": {"stringValue": win.updatedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedWeighInIds.add(win.id);
    }
    if (syncedWeighInIds.isNotEmpty) {
      await db.markWeighInsClean(syncedWeighInIds);
      count += syncedWeighInIds.length;
    }

    // 5. Measurements
    final dirtyMeasurements = await db.getDirtyMeasurements();
    final syncedMeasurementIds = <String>[];
    for (final m in dirtyMeasurements) {
      final docUrl = '$_baseUrl/users/$userId/measurements/${m.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": m.id},
          "date": {"stringValue": m.date},
          "type": {"stringValue": m.type},
          "valueCm": {"doubleValue": m.valueCm},
          "loggedAt": {"stringValue": m.loggedAt.toIso8601String()},
          "updatedAt": {"stringValue": m.updatedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedMeasurementIds.add(m.id);
    }
    if (syncedMeasurementIds.isNotEmpty) {
      await db.markMeasurementsClean(syncedMeasurementIds);
      count += syncedMeasurementIds.length;
    }

    // 6. Water Logs
    final dirtyWater = await db.getDirtyWaterLogs();
    final syncedWaterIds = <String>[];
    for (final wl in dirtyWater) {
      final docUrl = '$_baseUrl/users/$userId/water_logs/${wl.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": wl.id},
          "date": {"stringValue": wl.date},
          "mlAdded": {"integerValue": wl.mlAdded.toString()},
          "loggedAt": {"stringValue": wl.loggedAt.toIso8601String()},
          "updatedAt": {"stringValue": wl.loggedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedWaterIds.add(wl.id);
    }
    if (syncedWaterIds.isNotEmpty) {
      await db.markWaterLogsClean(syncedWaterIds);
      count += syncedWaterIds.length;
    }

    // 7. Custom Foods
    final dirtyFoods = await db.getDirtyCustomFoods();
    final syncedFoodIds = <String>[];
    for (final cf in dirtyFoods) {
      final docUrl = '$_baseUrl/users/$userId/custom_foods/${cf.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": cf.id},
          "name": {"stringValue": cf.name},
          "servingSize": {"doubleValue": cf.servingSize},
          "servingUnit": {"stringValue": cf.servingUnit},
          "calories": {"doubleValue": cf.calories},
          "proteinG": {"doubleValue": cf.proteinG},
          "carbsG": {"doubleValue": cf.carbsG},
          "fatG": {"doubleValue": cf.fatG},
          "fiberG": {"doubleValue": cf.fiberG},
          "updatedAt": {"stringValue": cf.updatedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) syncedFoodIds.add(cf.id);
    }
    if (syncedFoodIds.isNotEmpty) {
      await db.markCustomFoodsClean(syncedFoodIds);
      count += syncedFoodIds.length;
    }

    // 8. User Profile
    final user = await db.getUserProfile();
    if (user != null) {
      final docUrl = '$_baseUrl/users/$userId';
      final payload = {
        "fields": {
          "id": {"stringValue": user.id},
          "heightCm": {"doubleValue": user.heightCm},
          "weightKg": {"doubleValue": user.weightKg},
          "calorieTarget": {"integerValue": user.calorieTarget.toString()},
          "proteinTargetG": {"doubleValue": user.proteinTargetG},
          "carbTargetG": {"doubleValue": user.carbTargetG},
          "fatTargetG": {"doubleValue": user.fatTargetG},
          "waterTargetMl": {"integerValue": user.waterTargetMl.toString()},
          "stepsTarget": {"integerValue": user.stepsTarget.toString()},
          "updatedAt": {"stringValue": user.updatedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) count++;
    }

    // 9. Recipes
    final recipes = await db.getAllRecipes();
    for (final r in recipes) {
      final docUrl = '$_baseUrl/users/$userId/recipes/${r.id}';
      final payload = {
        "fields": {
          "id": {"stringValue": r.id},
          "name": {"stringValue": r.name},
          "mealSlot": {"stringValue": r.mealSlot},
          "calories": {"doubleValue": r.calories},
          "proteinG": {"doubleValue": r.proteinG},
          "carbsG": {"doubleValue": r.carbsG},
          "fatG": {"doubleValue": r.fatG},
          "ingredientsJson": {"stringValue": r.ingredientsJson},
          "method": {"stringValue": r.method},
          "updatedAt": {"stringValue": r.updatedAt.toIso8601String()},
        }
      };
      final ok = await _patchDocument(docUrl, payload, headers);
      if (ok) count++;
    }

    return count;
  }

  /// Pulls remote changes using scoped user subcollection queries with GET fallback
  Future<int> pullRemoteChanges(AppDatabase db) async {
    int count = 0;
    final headers = await _getAuthHeaders();
    if (headers == null) return 0;

    final lastSync = await _authService.getLastSyncTimestamp();
    final isFreshInstall = lastSync == null || lastSync.millisecondsSinceEpoch == 0;

    // 1. Pull User Profile (GET)
    try {
      final userRes = await _dio.get(
        '$_baseUrl/users/$userId',
        queryParameters: apiKey != null ? {'key': apiKey} : null,
        options: Options(headers: headers, validateStatus: (s) => s != null && s < 500),
      );
      if (userRes.statusCode == 200 && userRes.data != null) {
        final fields = userRes.data['fields'] as Map<String, dynamic>?;
        if (fields != null) {
          final remoteUpdatedAt = DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now();
          final localUser = await db.getUserProfile();
          if (localUser == null || remoteUpdatedAt.isAfter(localUser.updatedAt)) {
            await db.saveUserProfile(
              UsersCompanion(
                id: const Value('default_user'),
                heightCm: Value(_parseDouble(fields['heightCm']) ?? 160.0),
                weightKg: Value(_parseDouble(fields['weightKg']) ?? 62.0),
                calorieTarget: Value(_parseInt(fields['calorieTarget']) ?? 2350),
                proteinTargetG: Value(_parseDouble(fields['proteinTargetG']) ?? 155.0),
                carbTargetG: Value(_parseDouble(fields['carbTargetG']) ?? 260.0),
                fatTargetG: Value(_parseDouble(fields['fatTargetG']) ?? 70.0),
                waterTargetMl: Value(_parseInt(fields['waterTargetMl']) ?? 3000),
                stepsTarget: Value(_parseInt(fields['stepsTarget']) ?? 10000),
                updatedAt: Value(remoteUpdatedAt),
              ),
            );
            count++;
          }
        }
      }
    } catch (e) {
      debugPrint('Pull user profile note: $e');
    }

    // 2. Pull Diary Entries
    final remoteDiaryDocs = await _queryCollection('diary_entries', isFreshInstall ? null : lastSync, headers);
    final diaryCompanions = <DiaryEntriesCompanion>[];
    for (final doc in remoteDiaryDocs) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      diaryCompanions.add(
        DiaryEntriesCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          date: Value(fields['date']?['stringValue'] ?? ''),
          mealSlot: Value(fields['mealSlot']?['stringValue'] ?? 'snack'),
          foodName: Value(fields['foodName']?['stringValue'] ?? ''),
          portionQty: Value(_parseDouble(fields['portionQty']) ?? 1.0),
          portionUnit: Value(fields['portionUnit']?['stringValue'] ?? 'g'),
          calories: Value(_parseDouble(fields['calories']) ?? 0.0),
          proteinG: Value(_parseDouble(fields['proteinG']) ?? 0.0),
          carbsG: Value(_parseDouble(fields['carbsG']) ?? 0.0),
          fatG: Value(_parseDouble(fields['fatG']) ?? 0.0),
          fiberG: Value(_parseDouble(fields['fiberG']) ?? 0.0),
          loggedAt: Value(DateTime.tryParse(fields['loggedAt']?['stringValue'] ?? '') ?? DateTime.now()),
          isDirty: const Value(false),
          updatedAt: Value(DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now()),
        ),
      );
    }
    if (diaryCompanions.isNotEmpty) {
      await db.upsertDiaryEntriesBatch(diaryCompanions);
      count += diaryCompanions.length;
    }

    // 3. Pull Workouts
    final remoteWorkouts = await _queryCollection('workout_sessions', isFreshInstall ? null : lastSync, headers);
    final workoutCompanions = <WorkoutSessionsCompanion>[];
    for (final doc in remoteWorkouts) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      workoutCompanions.add(
        WorkoutSessionsCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          date: Value(fields['date']?['stringValue'] ?? ''),
          activityName: Value(fields['activityName']?['stringValue'] ?? ''),
          durationMin: Value(_parseInt(fields['durationMin']) ?? 30),
          intensity: Value(fields['intensity']?['stringValue'] ?? 'moderate'),
          caloriesBurned: Value(_parseDouble(fields['caloriesBurned']) ?? 0.0),
          source: Value(fields['source']?['stringValue'] ?? 'manual'),
          loggedAt: Value(DateTime.tryParse(fields['loggedAt']?['stringValue'] ?? '') ?? DateTime.now()),
          isDirty: const Value(false),
          updatedAt: Value(DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now()),
        ),
      );
    }
    if (workoutCompanions.isNotEmpty) {
      await db.upsertWorkoutsBatch(workoutCompanions);
      count += workoutCompanions.length;
    }

    // 4. Pull Workout Set Logs
    final remoteSetLogs = await _queryCollection('workout_set_logs', isFreshInstall ? null : lastSync, headers);
    final setLogCompanions = <WorkoutSetLogsCompanion>[];
    for (final doc in remoteSetLogs) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      setLogCompanions.add(
        WorkoutSetLogsCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          sessionId: Value(fields['sessionId']?['stringValue'] ?? ''),
          date: Value(fields['date']?['stringValue'] ?? ''),
          exerciseName: Value(fields['exerciseName']?['stringValue'] ?? ''),
          setIndex: Value(_parseInt(fields['setIndex']) ?? 1),
          weightKg: Value(_parseDouble(fields['weightKg']) ?? 0.0),
          reps: Value(_parseInt(fields['reps']) ?? 10),
          targetReps: Value(fields['targetReps']?['stringValue']),
          completed: Value(fields['completed']?['booleanValue'] ?? true),
          loggedAt: Value(DateTime.tryParse(fields['loggedAt']?['stringValue'] ?? '') ?? DateTime.now()),
          isDirty: const Value(false),
        ),
      );
    }
    if (setLogCompanions.isNotEmpty) {
      await db.upsertWorkoutSetLogsBatch(setLogCompanions);
      count += setLogCompanions.length;
    }

    // 5. Pull Weigh-Ins
    final remoteWeighIns = await _queryCollection('weigh_ins', isFreshInstall ? null : lastSync, headers);
    final weighInCompanions = <WeighInsCompanion>[];
    for (final doc in remoteWeighIns) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      weighInCompanions.add(
        WeighInsCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          date: Value(fields['date']?['stringValue'] ?? ''),
          weightKg: Value(_parseDouble(fields['weightKg']) ?? 62.0),
          rollingAvgKg: Value(_parseDouble(fields['rollingAvgKg'])),
          loggedAt: Value(DateTime.tryParse(fields['loggedAt']?['stringValue'] ?? '') ?? DateTime.now()),
          isDirty: const Value(false),
          updatedAt: Value(DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now()),
        ),
      );
    }
    if (weighInCompanions.isNotEmpty) {
      await db.upsertWeighInsBatch(weighInCompanions);
      count += weighInCompanions.length;
    }

    // 6. Pull Measurements
    final remoteMeasurements = await _queryCollection('measurements', isFreshInstall ? null : lastSync, headers);
    final measurementCompanions = <MeasurementsCompanion>[];
    for (final doc in remoteMeasurements) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      measurementCompanions.add(
        MeasurementsCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          date: Value(fields['date']?['stringValue'] ?? ''),
          type: Value(fields['type']?['stringValue'] ?? 'waist'),
          valueCm: Value(_parseDouble(fields['valueCm']) ?? 0.0),
          loggedAt: Value(DateTime.tryParse(fields['loggedAt']?['stringValue'] ?? '') ?? DateTime.now()),
          isDirty: const Value(false),
          updatedAt: Value(DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now()),
        ),
      );
    }
    if (measurementCompanions.isNotEmpty) {
      await db.upsertMeasurementsBatch(measurementCompanions);
      count += measurementCompanions.length;
    }

    // 7. Pull Water Logs
    final remoteWater = await _queryCollection('water_logs', isFreshInstall ? null : lastSync, headers);
    final waterCompanions = <WaterLogsCompanion>[];
    for (final doc in remoteWater) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      waterCompanions.add(
        WaterLogsCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          date: Value(fields['date']?['stringValue'] ?? ''),
          mlAdded: Value(_parseInt(fields['mlAdded']) ?? 250),
          loggedAt: Value(DateTime.tryParse(fields['loggedAt']?['stringValue'] ?? '') ?? DateTime.now()),
          isDirty: const Value(false),
        ),
      );
    }
    if (waterCompanions.isNotEmpty) {
      await db.upsertWaterLogsBatch(waterCompanions);
      count += waterCompanions.length;
    }

    // 8. Pull Custom Foods
    final remoteFoods = await _queryCollection('custom_foods', isFreshInstall ? null : lastSync, headers);
    final foodCompanions = <CustomFoodsCompanion>[];
    for (final doc in remoteFoods) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      foodCompanions.add(
        CustomFoodsCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          name: Value(fields['name']?['stringValue'] ?? ''),
          servingSize: Value(_parseDouble(fields['servingSize']) ?? 100.0),
          servingUnit: Value(fields['servingUnit']?['stringValue'] ?? 'g'),
          calories: Value(_parseDouble(fields['calories']) ?? 0.0),
          proteinG: Value(_parseDouble(fields['proteinG']) ?? 0.0),
          carbsG: Value(_parseDouble(fields['carbsG']) ?? 0.0),
          fatG: Value(_parseDouble(fields['fatG']) ?? 0.0),
          fiberG: Value(_parseDouble(fields['fiberG']) ?? 0.0),
          isDirty: const Value(false),
          updatedAt: Value(DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now()),
        ),
      );
    }
    if (foodCompanions.isNotEmpty) {
      await db.upsertCustomFoodsBatch(foodCompanions);
      count += foodCompanions.length;
    }

    // 9. Pull Recipes
    final remoteRecipes = await _queryCollection('recipes', isFreshInstall ? null : lastSync, headers);
    final recipeCompanions = <RecipesCompanion>[];
    for (final doc in remoteRecipes) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields == null) continue;
      recipeCompanions.add(
        RecipesCompanion(
          id: Value(fields['id']?['stringValue'] ?? ''),
          name: Value(fields['name']?['stringValue'] ?? ''),
          mealSlot: Value(fields['mealSlot']?['stringValue'] ?? 'snack'),
          calories: Value(_parseDouble(fields['calories']) ?? 0.0),
          proteinG: Value(_parseDouble(fields['proteinG']) ?? 0.0),
          carbsG: Value(_parseDouble(fields['carbsG']) ?? 0.0),
          fatG: Value(_parseDouble(fields['fatG']) ?? 0.0),
          ingredientsJson: Value(fields['ingredientsJson']?['stringValue'] ?? '[]'),
          method: Value(fields['method']?['stringValue'] ?? ''),
          updatedAt: Value(DateTime.tryParse(fields['updatedAt']?['stringValue'] ?? '') ?? DateTime.now()),
        ),
      );
    }
    if (recipeCompanions.isNotEmpty) {
      await db.insertRecipesBatch(recipeCompanions);
      count += recipeCompanions.length;
    }

    return count;
  }

  /// Scoped collection query: uses :runQuery under users/$userId with GET fallback and client-side timestamp filter
  Future<List<Map<String, dynamic>>> _queryCollection(
    String collectionName,
    DateTime? since,
    Map<String, String> headers,
  ) async {
    final List<Map<String, dynamic>> results = [];
    final isFreshInstall = since == null || since.millisecondsSinceEpoch == 0;

    // 1. Try structured :runQuery scoped to the user subcollection
    if (!isFreshInstall) {
      try {
        final queryUrl = '$_baseUrl/users/$userId:runQuery';
        final Map<String, dynamic> structuredQuery = {
          "from": [{"collectionId": collectionName}],
          "where": {
            "fieldFilter": {
              "field": {"fieldPath": "updatedAt"},
              "op": "GREATER_THAN",
              "value": {"stringValue": since.toIso8601String()}
            }
          }
        };

        final res = await _dio.post(
          queryUrl,
          data: jsonEncode({"structuredQuery": structuredQuery}),
          queryParameters: apiKey != null ? {'key': apiKey} : null,
          options: Options(headers: headers, validateStatus: (s) => s != null && s < 400),
        );

        if (res.statusCode == 200 && res.data is List) {
          for (final item in res.data) {
            if (item is Map<String, dynamic> && item['document'] != null) {
              results.add(item['document'] as Map<String, dynamic>);
            }
          }
          return results;
        }
      } catch (e) {
        debugPrint('Structured query on $collectionName failed, falling back to GET: $e');
      }
    }

    // 2. GET Fallback (for fresh install OR if structured :runQuery returned error / no composite index)
    try {
      final listUrl = '$_baseUrl/users/$userId/$collectionName';
      final res = await _dio.get(
        listUrl,
        queryParameters: apiKey != null ? {'key': apiKey} : null,
        options: Options(headers: headers, validateStatus: (s) => s != null && s < 400),
      );

      if (res.statusCode == 200 && res.data != null && res.data['documents'] is List) {
        for (final doc in res.data['documents']) {
          if (doc is Map<String, dynamic> && doc['fields'] != null) {
            // Client-side timestamp filter guard when since is specified
            if (since != null && since.millisecondsSinceEpoch > 0) {
              final fields = doc['fields'] as Map<String, dynamic>;
              final updatedAtStr = fields['updatedAt']?['stringValue'];
              if (updatedAtStr != null) {
                final docUpdatedAt = DateTime.tryParse(updatedAtStr);
                if (docUpdatedAt != null && !docUpdatedAt.isAfter(since)) {
                  continue; // Discard older/stale documents
                }
              }
            }
            results.add(doc);
          }
        }
      }
    } catch (e) {
      debugPrint('GET collection $collectionName fallback error: $e');
    }

    return results;
  }

  Future<bool> _patchDocument(String url, Map<String, dynamic> payload, Map<String, String> headers) async {
    try {
      final res = await _dio.patch(
        url,
        data: jsonEncode(payload),
        queryParameters: apiKey != null ? {'key': apiKey} : null,
        options: Options(headers: headers, validateStatus: (s) => s != null && s < 400),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Patch error for $url: $e');
      return false;
    }
  }

  double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is Map) {
      if (val['doubleValue'] != null) return (val['doubleValue'] as num).toDouble();
      if (val['integerValue'] != null) return double.tryParse(val['integerValue'].toString());
    }
    return null;
  }

  int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is Map) {
      if (val['integerValue'] != null) return int.tryParse(val['integerValue'].toString());
      if (val['doubleValue'] != null) return (val['doubleValue'] as num).toInt();
    }
    return null;
  }
}

