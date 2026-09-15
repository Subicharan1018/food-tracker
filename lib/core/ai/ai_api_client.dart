import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';
import '../local_db/app_database.dart';

class AiApiClient {
  final String _base;
  final Duration _timeout;
  final http.Client _client;

  AiApiClient({
    String? baseUrl,
    Duration? timeout,
    http.Client? client,
  })  : _base = baseUrl ?? ServerConfig.baseUrl,
        _timeout = timeout ?? ServerConfig.timeout,
        _client = client ?? http.Client();

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_base$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    }
    throw Exception('Server error ${response.statusCode}: ${response.body}');
  }

  Future<Map<String, dynamic>> requestMealPlan({
    required String userId,
    required List<DiaryEntry> todayDiary,
    required int todayWaterMl,
    String? fcmToken,
  }) =>
      _post('/ai/meal-plan', {
        'user_id': userId,
        'fcm_token': fcmToken,
        'today_water_ml': todayWaterMl,
        'today_diary': todayDiary
            .map((e) => {
                  'mealSlot': e.mealSlot,
                  'foodName': e.foodName,
                  'calories': e.calories,
                  'proteinG': e.proteinG,
                  'carbsG': e.carbsG,
                  'fatG': e.fatG,
                  'fiberG': e.fiberG,
                })
            .toList(),
      });

  Future<Map<String, dynamic>> requestWorkoutProgression({
    required String userId,
    String? fcmToken,
  }) =>
      _post('/ai/workout-progression', {
        'user_id': userId,
        'fcm_token': fcmToken,
      });

  Future<Map<String, dynamic>> parseFood({
    required String userId,
    required String input,
  }) =>
      _post('/ai/parse-food', {
        'user_id': userId,
        'input': input,
      });

  Future<void> triggerWeeklyDigest({
    required String userId,
    required String fcmToken,
    required String week,
  }) async {
    await _post('/ai/weekly-digest/trigger', {
      'user_id': userId,
      'fcm_token': fcmToken,
      'week': week,
    });
  }

  Future<Map<String, dynamic>?> fetchDigest({
    required String userId,
    required String week,
  }) async {
    final response = await _client
        .get(Uri.parse('$_base/ai/weekly-digest/$userId/$week'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>> verifyRecipes({required String userId}) =>
      _post('/ai/verify-recipes', {'user_id': userId});

  Future<bool> isServerReachable() async {
    try {
      final res = await _client
          .get(Uri.parse('$_base/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
