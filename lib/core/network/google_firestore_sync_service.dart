import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../local_db/app_database.dart';

class GoogleFirestoreSyncService {
  final Dio _dio = Dio();
  String projectId;
  String userId;
  String? apiKey;

  GoogleFirestoreSyncService({
    this.projectId = 'food-tracker-vigor',
    this.userId = 'default_user',
    this.apiKey,
  });

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Test connection to Google Cloud Firestore project
  Future<bool> testConnection() async {
    try {
      final url = '$_baseUrl/users/$userId';
      final response = await _dio.get(
        url,
        queryParameters: apiKey != null ? {'key': apiKey} : null,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      // 200 (found) or 404 (project exists, document doesn't yet exist) both mean project is reachable!
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      debugPrint('Firestore test connection error: $e');
      return false;
    }
  }

  /// Syncs all local dirty diary entries to Google Firestore
  Future<int> syncDiaryEntries(List<DiaryEntry> entries) async {
    int syncedCount = 0;
    for (final entry in entries) {
      try {
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

        final res = await _dio.patch(
          docUrl,
          data: jsonEncode(payload),
          queryParameters: apiKey != null ? {'key': apiKey} : null,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (s) => s != null && s < 400,
          ),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          syncedCount++;
        }
      } catch (e) {
        debugPrint('Failed to sync diary entry ${entry.id} to Firestore: $e');
      }
    }
    return syncedCount;
  }

  /// Syncs workout sessions to Google Firestore
  Future<int> syncWorkouts(List<WorkoutSession> workouts) async {
    int syncedCount = 0;
    for (final w in workouts) {
      try {
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

        final res = await _dio.patch(
          docUrl,
          data: jsonEncode(payload),
          queryParameters: apiKey != null ? {'key': apiKey} : null,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (s) => s != null && s < 400,
          ),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          syncedCount++;
        }
      } catch (e) {
        debugPrint('Failed to sync workout ${w.id} to Firestore: $e');
      }
    }
    return syncedCount;
  }

  /// Syncs weigh-ins to Google Firestore
  Future<int> syncWeighIns(List<WeighIn> weighIns) async {
    int syncedCount = 0;
    for (final win in weighIns) {
      try {
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

        final res = await _dio.patch(
          docUrl,
          data: jsonEncode(payload),
          queryParameters: apiKey != null ? {'key': apiKey} : null,
          options: Options(
            headers: {'Content-Type': 'application/json'},
            validateStatus: (s) => s != null && s < 400,
          ),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          syncedCount++;
        }
      } catch (e) {
        debugPrint('Failed to sync weigh-in ${win.id} to Firestore: $e');
      }
    }
    return syncedCount;
  }

  /// Syncs user profile and recomp targets to Google Firestore
  Future<bool> syncUserProfile(User user) async {
    try {
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

      final res = await _dio.patch(
        docUrl,
        data: jsonEncode(payload),
        queryParameters: apiKey != null ? {'key': apiKey} : null,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (s) => s != null && s < 400,
        ),
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('Failed to sync user profile to Firestore: $e');
      return false;
    }
  }
}
