import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/local_db/app_database.dart';

const _serializer = ValueSerializer.defaults(serializeDateTimeValuesAsString: true);

/// Everything on the phone as one JSON document, keyed by table.
Future<Map<String, dynamic>> buildExport(AppDatabase db) async {
  List<Map<String, dynamic>> rows(List<DataClass> list) => [for (final r in list) r.toJson(serializer: _serializer)];
  return {
    'app': 'Kinetik',
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'schemaVersion': db.schemaVersion,
    'profile': rows(await db.select(db.users).get()),
    'diaryEntries': rows(await db.select(db.diaryEntries).get()),
    'weighIns': rows(await db.select(db.weighIns).get()),
    'measurements': rows(await db.select(db.measurements).get()),
    'workoutSessions': rows(await db.select(db.workoutSessions).get()),
    'workoutSetLogs': rows(await db.select(db.workoutSetLogs).get()),
    'waterLogs': rows(await db.select(db.waterLogs).get()),
    'sleepLogs': rows(await db.select(db.sleepLogs).get()),
    'recipes': rows(await db.select(db.recipes).get()),
    'customFoods': rows(await db.select(db.customFoods).get()),
    'pantry': rows(await db.getAllInventoryItems()),
    'shoppingCart': rows(await db.getAllCartItems()),
  };
}

String _csv(List<String> header, Iterable<List<Object?>> rows) {
  String cell(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return [header, ...rows].map((r) => r.map(cell).join(',')).join('\n');
}

/// Writes the export (JSON + spreadsheet-friendly CSVs) and opens the share
/// sheet so it can be saved to Drive, Files, email, etc.
Future<void> shareExport(AppDatabase db) async {
  final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final dir = await getTemporaryDirectory();
  final data = await buildExport(db);

  final json = File('${dir.path}/kinetik-export-$stamp.json')
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));

  final diary = await (db.select(db.diaryEntries)..orderBy([(e) => OrderingTerm.asc(e.date)])).get();
  final meals = File('${dir.path}/kinetik-meals-$stamp.csv')
    ..writeAsStringSync(_csv(
      ['date', 'meal', 'food', 'qty', 'unit', 'kcal', 'protein_g', 'carbs_g', 'fat_g', 'fiber_g'],
      diary.map((e) => [e.date, e.mealSlot, e.foodName, e.portionQty, e.portionUnit, e.calories.round(), e.proteinG, e.carbsG, e.fatG, e.fiberG]),
    ));

  final weights = await (db.select(db.weighIns)..orderBy([(w) => OrderingTerm.asc(w.date)])).get();
  final weighIns = File('${dir.path}/kinetik-weight-$stamp.csv')
    ..writeAsStringSync(_csv(['date', 'weight_kg', 'rolling_avg_kg'], weights.map((w) => [w.date, w.weightKg, w.rollingAvgKg])));

  await SharePlus.instance.share(ShareParams(
    files: [XFile(json.path), XFile(meals.path), XFile(weighIns.path)],
    subject: 'Kinetik export $stamp',
  ));
}
