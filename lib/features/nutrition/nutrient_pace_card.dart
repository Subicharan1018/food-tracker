import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class NutrientPaceCard extends StatelessWidget {
  final Map<String, dynamic>? status;

  const NutrientPaceCard({super.key, required this.status});

  static const _nutrients = <_NutrientLabel>[
    _NutrientLabel('vitaminD_mcg', 'Vitamin D', 'mcg'),
    _NutrientLabel('b12_mcg', 'B12', 'mcg'),
    _NutrientLabel('iron_mg', 'Iron', 'mg'),
    _NutrientLabel('calcium_mg', 'Calcium', 'mg'),
    _NutrientLabel('magnesium_mg', 'Magnesium', 'mg'),
    _NutrientLabel('zinc_mg', 'Zinc', 'mg'),
    _NutrientLabel('potassium_mg', 'Potassium', 'mg'),
    _NutrientLabel('omega3_g', 'Omega-3', 'g'),
    _NutrientLabel('folate_mcg', 'Folate', 'mcg'),
  ];

  @override
  Widget build(BuildContext context) {
    final data = status ?? const <String, dynamic>{};
    final issues = data['issues'] is Map ? Map<String, dynamic>.from(data['issues'] as Map) : const <String, dynamic>{};
    final gaps = issues['nutrient_gaps'] is Map
        ? Map<String, dynamic>.from(issues['nutrient_gaps'] as Map)
        : const <String, dynamic>{};
    final updatedAt = data['updated_at']?.toString();
    final message = data['message']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart_outlined, color: AppColors.brandPrimary, size: 21),
              const SizedBox(width: 9),
              const Expanded(child: Text('Micronutrient pace', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
              const Text('SERVER CHECK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .7, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            updatedAt == null ? 'No completed check yet · scheduled at 11, 2, 5 & 9' : 'Last updated: ${_formatDate(updatedAt)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          if (issues['missed_logging'] == true)
            _Callout(icon: Icons.edit_note_rounded, text: 'Nothing logged yet. Add your meal to start nutrient tracking.'),
          if (message != null && message.isNotEmpty) ...[
            if (issues['missed_logging'] == true) const SizedBox(height: 8),
            _Callout(icon: Icons.tips_and_updates_outlined, text: message),
          ],
          if (issues.isEmpty)
            const Text('Log meals with measured ingredients to build today’s micronutrient pace.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (gaps.isNotEmpty) ...[
            if (message != null || issues['missed_logging'] == true) const SizedBox(height: 12),
            const Text('BEHIND PACE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: _nutrients.where((nutrient) => gaps.containsKey(nutrient.key)).map((nutrient) {
                final value = gaps[nutrient.key];
                final consumed = value is Map ? value['consumed'] : null;
                final expected = value is Map ? value['expected'] : null;
                return _GapChip(label: nutrient.label, detail: '${_number(consumed)}/${_number(expected)} ${nutrient.unit}');
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Only IFCT/verified-source values are counted. Unmatched ingredients stay marked as coverage pending.', style: TextStyle(fontSize: 10, height: 1.35, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  static String _number(dynamic value) {
    if (value is num) return value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '–';
  }

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${date.day}/${date.month} $hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _NutrientLabel {
  final String key;
  final String label;
  final String unit;
  const _NutrientLabel(this.key, this.label, this.unit);
}

class _Callout extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Callout({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [Icon(icon, color: AppColors.brandPrimary, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)))]),
  );
}

class _GapChip extends StatelessWidget {
  final String label;
  final String detail;
  const _GapChip({required this.label, required this.detail});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(color: AppColors.destructive.withValues(alpha: .12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.destructive.withValues(alpha: .35))),
    child: Text('$label · $detail', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
  );
}
