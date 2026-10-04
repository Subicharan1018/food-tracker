import 'package:flutter/material.dart';

import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/domain/meal_slots.dart';

/// The day as a timetable: one row per slot, logged food listed beneath.
/// Empty slots offer "log again" (same as last time) and add.
class MealSchedule extends StatelessWidget {
  final List<DiaryEntry> entries;
  final Map<String, List<String>> usual;
  final Map<String, String> repeatLabels;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRepeat;
  final ValueChanged<String> onDelete;

  const MealSchedule({
    super.key,
    required this.entries,
    required this.usual,
    required this.repeatLabels,
    required this.onAdd,
    required this.onRepeat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in mealSlots) ...[
          _SlotRow(
            slot: slot,
            entries: entries.where((e) => e.mealSlot == slot.key).toList(),
            usual: usual[slot.key],
            repeatLabel: repeatLabels[slot.key],
            onAdd: () => onAdd(slot.key),
            onRepeat: () => onRepeat(slot.key),
            onDelete: onDelete,
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  final MealSlot slot;
  final List<DiaryEntry> entries;
  final List<String>? usual;
  final String? repeatLabel;
  final VoidCallback onAdd;
  final VoidCallback onRepeat;
  final ValueChanged<String> onDelete;

  const _SlotRow({
    required this.slot,
    required this.entries,
    required this.usual,
    required this.repeatLabel,
    required this.onAdd,
    required this.onRepeat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = entries.fold<double>(0, (s, e) => s + e.calories);
    final protein = entries.fold<double>(0, (s, e) => s + e.proteinG);
    final logged = entries.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                child: Text(slot.timeLabel, style: AppTypography.dataSmall.copyWith(color: AppColors.textMuted)),
              ),
              Expanded(
                child: Text(
                  slot.label.toUpperCase(),
                  style: AppTypography.label.copyWith(
                    fontSize: 17,
                    color: logged ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
              if (logged)
                Text('${kcal.round()} kcal · ${protein.round()} g P', style: AppTypography.dataSmall),
              IconButton(
                tooltip: 'Add to ${slot.label}',
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 20),
                color: logged ? AppColors.textSecondary : AppColors.brandPrimary,
              ),
            ],
          ),
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Row(
                children: [
                  Expanded(
                    child: Text(e.foodName, style: AppTypography.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${e.calories.round()}', style: AppTypography.dataSmall),
                  IconButton(
                    tooltip: 'Remove ${e.foodName}',
                    onPressed: () => onDelete(e.id),
                    icon: const Icon(Icons.close, size: 16),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          if (!logged && repeatLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 64),
              child: Row(
                children: [
                  Expanded(
                    child: Text(repeatLabel!, style: AppTypography.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  TextButton(onPressed: onRepeat, child: const Text('Log again')),
                ],
              ),
            )
          else if (!logged && usual != null)
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 2),
              child: Text('Usually ${usual!.join(' + ')}', style: AppTypography.bodyMedium),
            ),
        ],
      ),
    );
  }
}
