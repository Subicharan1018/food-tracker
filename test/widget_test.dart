import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/core/local_db/seed_data.dart';
import 'package:food_tracker/main.dart';

void main() {
  testWidgets('Kinetik app smoke test — renders Home dashboard and calorie ring', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    await SeedData.seedInitialData(inMemoryDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
        ],
        child: const KinetikFitnessApp(),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    // Verify brand title and key dashboard elements
    expect(find.text('KINETIK'), findsOneWidget);
    expect(find.text('Recomp · Phase 1'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);

    await inMemoryDb.close();
  });
}
