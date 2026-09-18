import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../core/di/providers.dart';
import '../../core/local_db/app_database.dart';
import '../../core/theme/app_theme.dart';

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

  Future<void> _logMealItem(Map<String, dynamic> item) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final recipeName = item['recipe_name']?.toString() ?? 'Planned Meal';
    final mealSlot = item['meal_slot']?.toString().toLowerCase() ?? 'dinner';
    final calories = (item['calories'] as num?)?.toDouble() ?? 400.0;
    final proteinG = (item['protein'] as num?)?.toDouble() ?? 30.0;
    // Estimated balanced macros for recomp
    final carbsG = (item['carbs'] as num?)?.toDouble() ?? (calories * 0.45 / 4.0);
    final fatG = (item['fat'] as num?)?.toDouble() ?? ((calories - (proteinG * 4) - (carbsG * 4)) / 9.0).clamp(5.0, 30.0);

    await db.addDiaryEntry(
      DiaryEntriesCompanion.insert(
        id: const Uuid().v4(),
        date: dateStr,
        mealSlot: mealSlot,
        foodName: recipeName,
        portionQty: 1.0,
        portionUnit: 'serving',
        calories: calories,
        proteinG: proteinG,
        carbsG: carbsG,
        fatG: fatG,
        fiberG: const Value(4.0),
        loggedAt: Value(now),
        isDirty: const Value(true),
        updatedAt: Value(now),
      ),
    );

    setState(() {
      _loggedItems.add(recipeName);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logged "$recipeName" to $mealSlot! ✨'),
          backgroundColor: AppColors.positive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.positive, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tonight's Plan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'AI Recommendation • Generated at $timeStr',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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

          const SizedBox(height: 16),

          if (widget.planItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No specific meal items suggested for tonight.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...widget.planItems.map((rawItem) {
              final item = rawItem is Map<String, dynamic>
                  ? rawItem
                  : (rawItem as dynamic).toJson();
              final name = item['recipe_name']?.toString() ?? 'Recipe';
              final slot = item['meal_slot']?.toString().toUpperCase() ?? 'DINNER';
              final cal = (item['calories'] as num?)?.round() ?? 0;
              final prot = (item['protein'] as num?)?.round() ?? 0;
              final reasoning = item['reasoning']?.toString() ?? '';
              final isLogged = _loggedItems.contains(name);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            slot,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$cal kcal',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text('  •  ', style: TextStyle(color: AppColors.textMuted)),
                        Text(
                          '$prot g protein',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.positive,
                          ),
                        ),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              isLogged ? Icons.check_rounded : Icons.add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isLogged ? 'Logged' : 'Log meal',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLogged ? AppColors.surface : AppColors.positive,
                              foregroundColor: isLogged ? AppColors.positive : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isLogged ? null : () => _logMealItem(item),
                          ),
                        ),
                      ],
                    ),
                    if (reasoning.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reasoning,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
