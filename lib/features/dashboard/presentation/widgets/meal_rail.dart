import 'package:flutter/material.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import 'meal_slot_card.dart';
import 'meal_slot_timing.dart';

class MealRailItem {
  final String keyName, title, subtitle, time;
  final IconData icon;
  final List<DiaryEntry> entries;
  const MealRailItem({required this.keyName, required this.title, required this.subtitle, required this.time, required this.icon, required this.entries});
}

/// Shows the day's meals as a sequence, with only the selected slot expanded.
class MealRail extends StatefulWidget {
  final List<MealRailItem> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onDelete;
  const MealRail({super.key, required this.items, required this.onAdd, required this.onDelete});

  @override
  State<MealRail> createState() => _MealRailState();
}

class _MealRailState extends State<MealRail> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = _indexForSlot(mealSlotForTime(DateTime.now()));
  }

  int _indexForSlot(String slot) {
    final index = widget.items.indexWhere((item) => item.keyName == slot);
    return index >= 0 ? index : 0;
  }

  @override
  void didUpdateWidget(covariant MealRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.items.length) {
      _selected = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.items[_selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TODAY\'S MEALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8, color: AppColors.textMuted)),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => Container(width: 24, alignment: Alignment.center, child: Container(height: 1, color: AppColors.border)),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final active = index == _selected;
              final logged = item.entries.isNotEmpty;
              return InkWell(
                onTap: () => setState(() => _selected = index),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    children: [
                      Container(
                        width: index == 0 || index == widget.items.length - 2 ? 38 : 32,
                        height: index == 0 || index == widget.items.length - 2 ? 38 : 32,
                        decoration: BoxDecoration(
                          color: active ? AppColors.brandPrimary : (logged ? AppColors.positive : AppColors.cardElevated),
                          shape: BoxShape.circle,
                          border: Border.all(color: active || logged ? Colors.transparent : AppColors.border),
                        ),
                        child: Icon(item.icon, size: 17, color: active || logged ? AppColors.textInverse : AppColors.textSecondary),
                      ),
                      const SizedBox(height: 7),
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? AppColors.textPrimary : AppColors.textSecondary)),
                      Text(item.time, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        MealSlotCard(slotKey: selected.keyName, title: selected.title, subtitle: selected.subtitle, timeRange: selected.time, entries: selected.entries, onAddTap: () => widget.onAdd(selected.keyName), onDeleteEntry: widget.onDelete),
      ],
    );
  }
}
