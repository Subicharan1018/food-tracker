import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/core/di/providers.dart';
import 'package:food_tracker/core/local_db/app_database.dart';
import 'package:food_tracker/core/local_db/seed_data.dart';
import 'package:food_tracker/core/theme/app_theme.dart';
import 'package:intl/intl.dart';

/// Renders real screens to PNG for design review (no emulator needed).
/// Run:  RENDER_SCREENS=1 flutter test test/render
/// Output: build/screens/<name>.png  (gitignored)
final bool renderEnabled = Platform.environment.containsKey('RENDER_SCREENS');

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load(AppFonts.display, ['assets/fonts/BigShouldersDisplay.ttf']);
  await load(AppFonts.mono, [
    'assets/fonts/IBMPlexMono-Regular.ttf',
    'assets/fonts/IBMPlexMono-Medium.ttf',
    'assets/fonts/IBMPlexMono-SemiBold.ttf',
  ]);
  await load(AppFonts.body, ['assets/fonts/InstrumentSans.ttf']);
  // Material icons ship with the Flutter SDK, not the app bundle.
  final sdk = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}

String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// A realistic mid-afternoon day from the Recomp plan.
Future<AppDatabase> seededDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await SeedData.seedInitialData(db);
  await db.saveUserProfile(const UsersCompanion(
    id: Value('default_user'),
    calorieTarget: Value(2350),
    proteinTargetG: Value(155),
    carbTargetG: Value(260),
    fatTargetG: Value(70),
    waterTargetMl: Value(3000),
    stepsTarget: Value(10000),
  ));
  Future<void> eat(String slot, String food, double kcal, double p, double c, double f, {String date = '', double qty = 1, String unit = 'serving'}) =>
      db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
            id: '$slot-$food-${date.isEmpty ? today : date}',
            date: date.isEmpty ? today : date,
            mealSlot: slot,
            foodName: food,
            portionQty: qty,
            portionUnit: unit,
            calories: kcal,
            proteinG: p,
            carbsG: c,
            fatG: f,
            fiberG: const Value(4),
          ));
  await eat('breakfast', 'Chapati', 360, 11, 66, 6, qty: 3, unit: 'piece');
  await eat('breakfast', 'Egg bhurji', 148, 12, 2, 10);
  await eat('lunch', 'Chapati', 240, 7, 44, 4, qty: 2, unit: 'piece');
  await eat('lunch', 'Chicken dry pack', 200, 35, 3, 6);
  await eat('shake', 'Whey protein', 114, 27, 2, 1, qty: 1, unit: 'scoop');
  final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
  await eat('dinner', 'Rice', 205, 4, 45, 0, date: yesterday);
  await eat('dinner', 'Chicken curry', 420, 64, 8, 14, date: yesterday);
  for (var i = 0; i < 3; i++) {
    await db.into(db.waterLogs).insert(WaterLogsCompanion.insert(id: 'w$i', date: today, mlAdded: 500));
  }
  for (final (d, kg) in [(21, 63.4), (14, 63.0), (7, 62.6), (0, 62.3)]) {
    await db.saveWeighIn(DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: d))), kg);
  }
  return db;
}

const paceStatus = <String, dynamic>{
  'updated_at': '2026-10-02T11:30:00Z',
  'message': 'Make Keerai Kootu tonight — your pantry already has everything, and it closes most of the iron gap.',
  'issues': {
    'nutrient_gaps': {
      'iron_mg': {'consumed': 4.1, 'expected': 11.4},
      'folate_mcg': {'consumed': 62, 'expected': 180},
    },
  },
  'candidate_recipe': {
    'name': 'Keerai Kootu',
    'nutrient': 'iron_mg',
    'per_serving_amount': 5.2,
    'makeable': true,
    'missing_ingredients': [],
  },
  'uncounted_foods': ['Chicken dry pack'],
};

/// Pumps [screen] at phone width and writes build/screens/<name>.png.
Future<void> renderScreen(
  WidgetTester tester,
  String name,
  Widget screen, {
  required AppDatabase db,
  List overrides = const [],
  double height = 1600,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(412 * 2, height * 2);
  addTearDown(tester.view.reset);
  final key = GlobalKey();

  await tester.runAsync(() async {
    await loadFonts();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        todayStepsProvider.overrideWith((ref) async => 6420),
        dailyPaceProvider.overrideWith((ref) async => paceStatus),
        firestoreUserIdProvider.overrideWith((ref) async => 'render'),
        ...overrides.cast(),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.darkTheme, home: screen),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 400));
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/screens/$name.png')..createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}
