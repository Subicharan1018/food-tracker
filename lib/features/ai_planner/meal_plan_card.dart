import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/di/providers.dart';
import '../../core/ingredients/ingredient_identity.dart';
import '../../core/local_db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ledger.dart';
import '../pantry/pantry_service.dart';

/// The AI's evening suggestions.
///
/// The AI only chooses *which* recipe; every number shown or logged comes
/// from that recipe in your recipe box.  A suggestion that isn't one of your
/// recipes can't be logged from here, because there are no real numbers for it.
class MealPlanCard extends ConsumerStatefulWidget {
  final List<dynamic> planItems;
  final String? rawText;
  final VoidCallback? onDismiss;

  const MealPlanCard({
    super.key,
    required this.planItems,
    this.rawText,
    this.onDismiss,
  });

  @override
  ConsumerState<MealPlanCard> createState() => _MealPlanCardState();
}

class _MealPlanCardState extends ConsumerState<MealPlanCard> {
  final Set<String> _loggedItems = {};

  Future<void> _log(Recipe recipe, String mealSlot) async {
    final report = await logRecipe(
      ref.read(databaseProvider),
      recipe,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      mealSlot: mealSlot,
    );
    setState(() => _loggedItems.add(recipe.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(['Logged ${recipe.name}.', ?report.summary].join(' '))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesStreamProvider).value ?? const <Recipe>[];
    final byName = {for (final r in recipes) canonicalizeIngredient(r.name): r};
    final timeStr = DateFormat('h:mm a').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tonight's Plan", style: AppTypography.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Suggested at $timeStr from your recipes',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (widget.onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                onPressed: widget.onDismiss,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.planItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No meals suggested for tonight.', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          for (final rawItem in widget.planItems) ...[
            _PlanRow(
              item: rawItem is Map<String, dynamic> ? rawItem : (rawItem as dynamic).toJson() as Map<String, dynamic>,
              byName: byName,
              logged: _loggedItems,
              onLog: _log,
            ),
            const Hairline(indent: 0),
          ],
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final Map<String, Recipe> byName;
  final Set<String> logged;
  final Future<void> Function(Recipe, String) onLog;

  const _PlanRow({required this.item, required this.byName, required this.logged, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final name = item['recipe_name']?.toString() ?? 'Recipe';
    final slot = item['meal_slot']?.toString().toLowerCase() ?? 'dinner';
    final reasoning = item['reasoning']?.toString() ?? '';
    final recipe = byName[canonicalizeIngredient(name)];
    final isLogged = recipe != null && logged.contains(recipe.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  recipe?.name ?? name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              Text(slot, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 4),
          if (recipe != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${recipe.calories.round()} kcal · ${recipe.proteinG.round()} g protein',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFeatures: tabularFigures),
                  ),
                ),
                TextButton(
                  onPressed: isLogged ? null : () => onLog(recipe, slot),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    disabledForegroundColor: AppColors.textMuted,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: Text(isLogged ? 'Logged' : 'Log meal'),
                ),
              ],
            )
          else
            const Text(
              "Not in your recipe box, so there are no numbers to log. Add it as a recipe, or log it from search.",
              style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMuted),
            ),
          if (reasoning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reasoning, style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}
