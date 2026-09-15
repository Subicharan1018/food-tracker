import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/ai/ai_api_client.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/features/food_logging/nlp_input_widget.dart';

class FakeAiApiClient extends AiApiClient {
  final Map<String, dynamic> fakeResponse;
  final bool shouldThrow;

  FakeAiApiClient({required this.fakeResponse, this.shouldThrow = false});

  @override
  Future<Map<String, dynamic>> parseFood({required String userId, required String input}) async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return fakeResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NlpInputWidget parses text and triggers onParsed callback', (tester) async {
    final parsedResults = <Map<String, dynamic>>[];
    final fallbackQueries = <String>[];

    final fakeClient = FakeAiApiClient(fakeResponse: {
      'items': [
        {'food_name': 'Egg Bhurji', 'portion_qty': 2.0, 'meal_slot': 'breakfast'}
      ]
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiApiClientProvider.overrideWithValue(fakeClient),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NlpInputWidget(
              onParsed: (items) => parsedResults.addAll(items),
              onFallbackSearch: (q) => fallbackQueries.add(q),
            ),
          ),
        ),
      ),
    );

    // Enter query
    await tester.enterText(find.byType(TextField), '2 egg bhurji');
    await tester.pump();

    // Tap Parse
    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(parsedResults.length, 1);
    expect(parsedResults.first['food_name'], 'Egg Bhurji');
    expect(fallbackQueries, isEmpty);
  });

  testWidgets('NlpInputWidget triggers onFallbackSearch on empty or failed server response', (tester) async {
    final parsedResults = <Map<String, dynamic>>[];
    final fallbackQueries = <String>[];

    final failingClient = FakeAiApiClient(fakeResponse: {}, shouldThrow: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiApiClientProvider.overrideWithValue(failingClient),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NlpInputWidget(
              onParsed: (items) => parsedResults.addAll(items),
              onFallbackSearch: (q) => fallbackQueries.add(q),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'unknown food text');
    await tester.pump();

    await tester.tap(find.text('Parse'));
    await tester.pumpAndSettle();

    expect(parsedResults, isEmpty);
    expect(fallbackQueries, ['unknown food text']);
  });
}
