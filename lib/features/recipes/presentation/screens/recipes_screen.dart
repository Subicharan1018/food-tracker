import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../streaks/services/streak_service.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _selectedSlot = 'all';

  void _showRecipeDetail(Recipe recipe) {
    List<String> ingredients = [];
    try {
      final decoded = jsonDecode(recipe.ingredientsJson);
      if (decoded is List) {
        ingredients = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(recipe.name, style: AppTypography.titleLarge),
                          if (recipe.tamilName != null)
                            Text(recipe.tamilName!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        recipe.mealSlot.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Macro card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _RecipeStat(label: 'Calories', value: '${recipe.calories.toInt()} kcal', color: AppColors.textPrimary),
                      _RecipeStat(label: 'Protein', value: '${recipe.proteinG}g', color: AppColors.textPrimary),
                      _RecipeStat(label: 'Carbs', value: '${recipe.carbsG}g', color: AppColors.textPrimary),
                      _RecipeStat(label: 'Fat', value: '${recipe.fatG}g', color: AppColors.textPrimary),
                    ],
                  ),
                ),

                if (recipe.shelfLifeTip != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.attention.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.attention.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.attention, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            recipe.shelfLifeTip!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                const Text('INGREDIENTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ...ingredients.map(
                  (ing) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(ing, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('COOKING METHOD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(recipe.method, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),

                const SizedBox(height: 24),
                // 1-Tap Log Meal button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: AppColors.textInverse,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final db = ref.read(databaseProvider);
                      final dateStr = ref.read(formattedSelectedDateProvider);

                      await db.addDiaryEntry(
                        DiaryEntriesCompanion.insert(
                          id: const Uuid().v4(),
                          date: dateStr,
                          mealSlot: recipe.mealSlot,
                          foodName: recipe.name,
                          portionQty: 1.0,
                          portionUnit: 'recipe meal',
                          calories: recipe.calories,
                          proteinG: recipe.proteinG,
                          carbsG: recipe.carbsG,
                          fatG: recipe.fatG,
                          fiberG: Value(recipe.fiberG),
                          loggedAt: Value(DateTime.now()),
                        ),
                      );

                      // Update logging streak
                      final currentStreak = await db.getStreak('logging');
                      final streakRes = StreakEngine.processActivity(
                        currentCount: currentStreak?.currentCount ?? 0,
                        longestCount: currentStreak?.longestCount ?? 0,
                        lastActiveDate: currentStreak?.lastActiveDate,
                        today: DateTime.now(),
                      );
                      await db.updateStreak(
                        StreaksCompanion.insert(
                          type: 'logging',
                          currentCount: Value(streakRes.currentCount),
                          longestCount: Value(streakRes.longestCount),
                          lastActiveDate: Value(streakRes.lastActiveDate),
                          updatedAt: Value(DateTime.now()),
                        ),
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logged ${recipe.name} to ${recipe.mealSlot.toUpperCase()}!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text('Log 1x Meal (${recipe.calories.toInt()} kcal)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recomp Recipe Box'),
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ChipItem(label: 'All Recipes', value: 'all', selected: _selectedSlot == 'all', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _ChipItem(label: 'Breakfast', value: 'breakfast', selected: _selectedSlot == 'breakfast', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _ChipItem(label: 'Lunch (Dry-pack)', value: 'lunch', selected: _selectedSlot == 'lunch', onSelect: (v) => setState(() => _selectedSlot = v)),
                  const SizedBox(width: 8),
                  _ChipItem(label: 'Dinner (Curries)', value: 'dinner', selected: _selectedSlot == 'dinner', onSelect: (v) => setState(() => _selectedSlot = v)),
                ],
              ),
            ),
          ),

          Expanded(
            child: recipesAsync.when(
              data: (allRecipes) {
                final recipes = _selectedSlot == 'all'
                    ? allRecipes
                    : allRecipes.where((r) => r.mealSlot == _selectedSlot).toList();

                if (recipes.isEmpty) {
                  return const Center(child: Text('No recipes found for category.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: recipes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final r = recipes[index];

                    return InkWell(
                      onTap: () => _showRecipeDetail(r),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    '${r.calories.toInt()} kcal',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            if (r.tamilName != null) ...[
                              const SizedBox(height: 2),
                              Text(r.tamilName!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _MacroBadge(label: 'P', value: '${r.proteinG}g', color: AppColors.textPrimary),
                                const SizedBox(width: 8),
                                _MacroBadge(label: 'C', value: '${r.carbsG}g', color: AppColors.textPrimary),
                                const SizedBox(width: 8),
                                _MacroBadge(label: 'F', value: '${r.fatG}g', color: AppColors.textPrimary),
                                const Spacer(),
                                const Text('View Recipe & 1-Tap Log →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.textPrimary)),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _RecipeStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _ChipItem extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelect;

  const _ChipItem({required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelect(value),
      selectedColor: AppColors.surfaceElevated,
      backgroundColor: AppColors.card,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
      ),
      side: BorderSide(color: selected ? AppColors.textPrimary : AppColors.border),
      showCheckmark: false,
    );
  }
}
