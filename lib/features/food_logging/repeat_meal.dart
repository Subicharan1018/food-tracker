import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ingredients/ingredient_identity.dart';
import '../../core/local_db/app_database.dart';
import '../pantry/pantry_service.dart';

/// Copies a previously logged meal onto [date].
///
/// Recipe meals are re-logged through [logRecipe] using the recipe's current
/// numbers (and they use pantry stock); everything else is copied as logged,
/// keeping the IFCT link so its micronutrients still count.
Future<PantryUseReport> repeatMeal(AppDatabase db, List<DiaryEntry> entries, {required String date}) async {
  final recipes = {for (final r in await db.getAllRecipes()) canonicalizeIngredient(r.name): r};
  final used = <String>[];
  final notTracked = <String>[];
  for (final e in entries) {
    final recipe = e.portionUnit == 'recipe meal' ? recipes[canonicalizeIngredient(e.foodName)] : null;
    if (recipe != null) {
      final report = await logRecipe(db, recipe, date: date, mealSlot: e.mealSlot, portions: e.portionQty);
      used.addAll(report.used);
      notTracked.addAll(report.notTracked);
      continue;
    }
    await db.logDiaryEntry(DiaryEntriesCompanion.insert(
      id: const Uuid().v4(),
      date: date,
      mealSlot: e.mealSlot,
      foodItemId: Value(e.foodItemId),
      customFoodId: Value(e.customFoodId),
      foodName: e.foodName,
      portionQty: e.portionQty,
      portionUnit: e.portionUnit,
      calories: e.calories,
      proteinG: e.proteinG,
      carbsG: e.carbsG,
      fatG: e.fatG,
      fiberG: Value(e.fiberG),
      loggedAt: Value(DateTime.now()),
    ));
  }
  return PantryUseReport(used, notTracked);
}

/// "Same as Tue: Chapati + Egg bhurji"
String repeatLabel(List<DiaryEntry> entries) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final day = days[DateTime.parse(entries.first.date).weekday - 1];
  final names = entries.map((e) => e.foodName).toList();
  final shown = names.length > 3 ? [...names.take(3), '+${names.length - 3}'] : names;
  return 'Same as $day: ${shown.join(' + ')}';
}
