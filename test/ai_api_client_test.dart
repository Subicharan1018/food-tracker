import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:food_tracker/core/ai/ai_api_client.dart';
import 'package:food_tracker/core/local_db/app_database.dart';

void main() {
  group('AiApiClient Tests', () {
    test('requestMealPlan sends serialized diary and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/ai/meal-plan');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['user_id'], 'user_123');
        expect(body['today_water_ml'], 1500);
        expect((body['today_diary'] as List).length, 1);

        return http.Response(
          jsonEncode({
            'plan': [
              {
                'recipe_name': 'Chicken Biryani',
                'meal_slot': 'dinner',
                'calories': 550,
                'protein': 42,
                'reasoning': 'High protein post-workout'
              }
            ],
            'raw_text': '[]'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AiApiClient(
        baseUrl: 'http://test-server',
        client: mockClient,
      );

      final entry = DiaryEntry(
        id: '1',
        mealSlot: 'lunch',
        foodName: 'Chapati',
        portionQty: 1.0,
        portionUnit: 'serving',
        calories: 300,
        proteinG: 10,
        carbsG: 50,
        fatG: 6,
        fiberG: 4,
        isDirty: false,
        date: '2026-09-14',
        loggedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final res = await client.requestMealPlan(
        userId: 'user_123',
        todayDiary: [entry],
        todayWaterMl: 1500,
      );

      expect(res['plan'], isNotNull);
      expect((res['plan'] as List).first['recipe_name'], 'Chicken Biryani');
    });

    test('parseFood sends NLP query and parses response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/ai/parse-food');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['input'], '2 eggs and dosa');

        return http.Response(
          jsonEncode({
            'items': [
              {'food_name': 'Egg', 'portion_qty': 2.0, 'meal_slot': 'breakfast'}
            ],
            'raw_text': '[]'
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AiApiClient(
        baseUrl: 'http://test-server',
        client: mockClient,
      );

      final res = await client.parseFood(
        userId: 'user_123',
        input: '2 eggs and dosa',
      );

      expect(res['items'], isNotNull);
      expect((res['items'] as List).first['food_name'], 'Egg');
    });

    test('createRecipe sends pasted recipe, meal slot, and servings', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/ai/recipes');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['user_id'], 'user_123');
        expect(body['meal_slot'], 'lunch');
        expect(body['servings'], 2.0);
        expect((body['recipe_text'] as String).contains('Paneer'), isTrue);

        return http.Response(
          jsonEncode({
            'id': 'palak_paneer_abc',
            'name': 'Palak Paneer',
            'meal_slot': 'lunch',
            'servings': 2,
            'calories': 320,
            'protein_g': 22,
            'carbs_g': 15,
            'fat_g': 18,
            'fiber_g': 5,
            'ingredients': [],
            'warnings': [],
            'stored': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = AiApiClient(baseUrl: 'http://test-server', client: mockClient);
      final res = await client.createRecipe(
        userId: 'user_123',
        recipeText: 'Palak Paneer\n- Paneer — 150 g',
        mealSlot: 'lunch',
        servings: 2,
      );

      expect(res['name'], 'Palak Paneer');
      expect(res['stored'], isTrue);
    });

    test('fetchDigest returns parsed map on 200 and null on non-200', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('2026-W37')) {
          return http.Response(
            jsonEncode({'week': '2026-W37', 'content': 'Great week!', 'cached': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = AiApiClient(
        baseUrl: 'http://test-server',
        client: mockClient,
      );

      final digest = await client.fetchDigest(userId: 'u1', week: '2026-W37');
      expect(digest, isNotNull);
      expect(digest?['content'], 'Great week!');

      final empty = await client.fetchDigest(userId: 'u1', week: '2026-W99');
      expect(empty, isNull);
    });

    test('isServerReachable returns true on 200 and false on error', () async {
      final okClient = MockClient((req) async => http.Response('{"status":"ok"}', 200));
      final failClient = MockClient((req) async => http.Response('Error', 500));

      final client1 = AiApiClient(baseUrl: 'http://test', client: okClient);
      final client2 = AiApiClient(baseUrl: 'http://test', client: failClient);

      expect(await client1.isServerReachable(), isTrue);
      expect(await client2.isServerReachable(), isFalse);
    });
  });
}
