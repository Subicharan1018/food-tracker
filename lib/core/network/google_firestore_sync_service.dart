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
    this.projectId = 'food-tracker-vigor',
    this.userId = 'default_user',
    this.apiKey,
  })  : _dio = dio ?? Dio(),
        _authService = authService ?? FirebaseAuthRestService();

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getValidIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Test connection to Google Cloud Firestore project with authentication
  Future<bool> testConnection() async {
    try {
      userId = await _authService.getUserId();
      final headers = await _getAuthHeaders();
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
      // 200 (found) or 404 (project reachable, user doc not yet created) both indicate reachability!
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      debugPrint('Firestore test connection error: $e');
      return false;
    }
  }

  /// Full Two-Way Sync: Pushes all local dirty rows, pulls remote updates via :runQuery
  Future<SyncResult> syncAll(AppDatabase db) async {
    int totalPushed = 0;
    int totalPulled = 0;

    try {
      userId = await _authService.getUserId();

      // 1. PUSH local dirty records
      totalPushed = await syncDirtyRecords(db);

      // 2. PULL remote updates
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

  /// Pushes all records across all 9 user collections marked isDirty == true
  Future<int> syncDirtyRecords(AppDatabase db) async {
    int count = 0;
    final headers = await _getAuthHeaders();

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

    // 3. Weigh-Ins
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

    // 4. Measurements (keyed on measurement id - never collides across same date)
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

    // 5. Water Logs
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

    // 6. Custom Foods
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

    // 7. User Profile
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

    // 8. Recipes
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

  /// Pulls remote changes using :runQuery where updatedAt > lastSyncTimestamp (or all on fresh install)
  Future<int> pullRemoteChanges(AppDatabase db) async {
    int count = 0;
    final headers = await _getAuthHeaders();
    final lastSync = await _authService.getLastSyncTimestamp();
    final isFreshInstall = lastSync == null || lastSync.millisecondsSinceEpoch == 0;

    // 1. Pull User Profile (GET)
    try {
      final userRes = await _dio.get(
        '$_baseUrl/users/$userId',
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

    // 2. Pull Diary Entries (:runQuery)
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

    // 4. Pull Weigh-Ins
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

    // 5. Pull Measurements
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

    // 6. Pull Water Logs
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

    // 7. Pull Custom Foods
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

    return count;
  }

  Future<List<Map<String, dynamic>>> _queryCollection(
    String collectionName,
    DateTime? since,
    Map<String, String> headers,
  ) async {
    final List<Map<String, dynamic>> results = [];
    try {
      final url = '$_baseUrl:runQuery';
      final Map<String, dynamic> structuredQuery = {
        "from": [{"collectionId": collectionName}],
      };

      if (since != null) {
        structuredQuery["where"] = {
          "fieldFilter": {
            "field": {"fieldPath": "updatedAt"},
            "op": "GREATER_THAN",
            "value": {"stringValue": since.toIso8601String()}
          }
        };
      }

      final res = await _dio.post(
        url,
        data: jsonEncode({"structuredQuery": structuredQuery}),
        options: Options(headers: headers, validateStatus: (s) => s != null && s < 400),
      );

      if (res.statusCode == 200 && res.data is List) {
        for (final item in res.data) {
          if (item is Map<String, dynamic> && item['document'] != null) {
            results.add(item['document'] as Map<String, dynamic>);
          }
        }
      }
    } catch (e) {
      debugPrint('Query $collectionName error: $e');
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
