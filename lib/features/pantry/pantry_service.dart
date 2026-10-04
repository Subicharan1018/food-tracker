import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ingredients/ingredient_identity.dart';
import '../../core/local_db/app_database.dart';
import '../shopping_cart/shopping_cart_service.dart' show convertQuantity;

/// What logging a recipe did to the pantry.
class PantryUseReport {
  /// "100 g paneer" style lines for what was taken out.
  final List<String> used;

  /// Ingredients with no pantry row, or in a unit that can't be converted.
  final List<String> notTracked;

  const PantryUseReport(this.used, this.notTracked);

  String? get summary {
    if (used.isEmpty) return null;
    return 'Used ${used.join(', ')} from the pantry';
  }
}

const _countUnits = {'', 'piece', 'pieces', 'pc', 'pcs', 'small', 'medium', 'large', 'whole', 'nos', 'no'};

/// Ingredient amount expressed in [pantryUnit], or `null` if it can't be.
double? _amountInPantryUnit(Map<String, dynamic> ingredient, String pantryUnit, double factor) {
  final grams = (ingredient['grams'] as num?)?.toDouble();
  if (grams != null && grams > 0) {
    final converted = convertQuantity(grams * factor, 'g', pantryUnit);
    if (converted != null) return converted;
  }
  final amount = (ingredient['amount'] as num?)?.toDouble();
  if (amount == null || amount <= 0) return null;
  final unit = (ingredient['unit']?.toString() ?? '').trim().toLowerCase();
  if (pantryUnit == 'pieces' && _countUnits.contains(unit)) return amount * factor;
  return convertQuantity(amount * factor, unit, pantryUnit);
}

/// Logs one recipe to the diary and takes its ingredients out of the pantry.
///
/// [portions] is how many servings were eaten; ingredient amounts in the
/// recipe make `recipe.servings` servings.  Deleting the diary entry later
/// puts the stock back (see [AppDatabase.deleteDiaryEntry]).
Future<PantryUseReport> logRecipe(
  AppDatabase db,
  Recipe recipe, {
  required String date,
  required String mealSlot,
  double portions = 1.0,
}) {
  return db.transaction(() async {
    final entryId = const Uuid().v4();
    await db.logDiaryEntry(DiaryEntriesCompanion.insert(
      id: entryId,
      date: date,
      mealSlot: mealSlot,
      foodName: recipe.name,
      portionQty: portions,
      portionUnit: 'recipe meal',
      calories: recipe.calories * portions,
      proteinG: recipe.proteinG * portions,
      carbsG: recipe.carbsG * portions,
      fatG: recipe.fatG * portions,
      fiberG: Value(recipe.fiberG * portions),
      loggedAt: Value(DateTime.now()),
    ));
    return _consume(db, recipe, entryId, portions / (recipe.servings > 0 ? recipe.servings : 1.0));
  });
}

Future<PantryUseReport> _consume(AppDatabase db, Recipe recipe, String entryId, double factor) async {
  final used = <String>[];
  final notTracked = <String>[];
  List<dynamic> ingredients;
  try {
    final decoded = jsonDecode(recipe.ingredientsJson);
    ingredients = decoded is List ? decoded : const [];
  } catch (_) {
    ingredients = const [];
  }

  for (final raw in ingredients.whereType<Map>()) {
    final ingredient = Map<String, dynamic>.from(raw);
    final name = (ingredient['ingredient'] ?? ingredient['name'] ?? '').toString().trim();
    final canonical = canonicalizeIngredient(name);
    if (canonical.isEmpty || canonical == 'water') continue;

    InventoryItem? row;
    double? need;
    for (final candidate in await db.getInventoryItemsByCanonicalName(canonical)) {
      need = _amountInPantryUnit(ingredient, candidate.unit, factor);
      if (need != null) {
        row = candidate;
        break;
      }
    }
    if (row == null || need == null || need <= 0) {
      notTracked.add(name);
      continue;
    }
    // Never below zero: the pantry may have been under-recorded.
    final taken = need > row.quantity ? row.quantity : need;
    if (taken <= 0) {
      notTracked.add(name);
      continue;
    }
    await db.incrementInventoryQuantity(row.id, -taken);
    await db.into(db.pantryUsages).insert(PantryUsagesCompanion.insert(
      diaryEntryId: entryId,
      inventoryItemId: row.id,
      name: row.name,
      canonicalName: row.canonicalName,
      amount: taken,
      unit: row.unit,
    ));
    used.add('${_fmt(taken)} ${row.unit} ${row.name.toLowerCase()}');
  }
  return PantryUseReport(used, notTracked);
}

String _fmt(double q) => q % 1 == 0 ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
