import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/ai_digest/weekly_digest_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WeeklyDigestCard renders cached weekly report content', (tester) async {
    final mockData = {
      'week': '2026-W37',
      'cached': true,
      'content': 'Great nutrition adherence: hit 155g protein 6/7 days. 4 training sessions completed.',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyDigestCard(
            initialData: mockData,
            weekOverride: '2026-W37',
          ),
        ),
      ),
    );

    expect(find.text('Weekly Recomp Digest (2026-W37)'), findsOneWidget);
    expect(find.text('Nutrition · Training · Body Signal'), findsOneWidget);
    expect(
      find.text('Great nutrition adherence: hit 155g protein 6/7 days. 4 training sessions completed.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });
}
