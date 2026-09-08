import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MacroBarsGrid extends StatelessWidget {
  final double proteinConsumed;
  final double proteinTarget;
  final double carbsConsumed;
  final double carbsTarget;
  final double fatConsumed;
  final double fatTarget;
  final double fiberConsumed;
  final double fiberTarget;

  const MacroBarsGrid({
    super.key,
    required this.proteinConsumed,
    required this.proteinTarget,
    required this.carbsConsumed,
    required this.carbsTarget,
    required this.fatConsumed,
    required this.fatTarget,
    this.fiberConsumed = 0.0,
    this.fiberTarget = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MacroCard(
                name: 'Protein',
                consumed: proteinConsumed,
                target: proteinTarget,
                unit: 'g',
                icon: Icons.fitness_center_rounded,
                isProtein: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                name: 'Carbs',
                consumed: carbsConsumed,
                target: carbsTarget,
                unit: 'g',
                icon: Icons.bolt_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MacroCard(
                name: 'Fat',
                consumed: fatConsumed,
                target: fatTarget,
                unit: 'g',
                icon: Icons.pie_chart_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                name: 'Fiber',
                consumed: fiberConsumed,
                target: fiberTarget,
                unit: 'g',
                icon: Icons.eco_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String name;
  final double consumed;
  final double target;
  final String unit;
  final IconData icon;
  final bool isProtein;

  const _MacroCard({
    required this.name,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.icon,
    this.isProtein = false,
  });

  Color _resolveColor() {
    if (target <= 0) return AppColors.textPrimary;
    // Special-cased Protein: White in-progress, Green when reached or exceeded. NEVER turns Amber.
    if (isProtein) {
      return consumed >= target ? AppColors.positive : AppColors.textPrimary;
    }
    // Carbs, Fat, Fiber: White in-progress, Green 95-105%, Amber over 105%
    if (consumed > target * 1.05) {
      return AppColors.attention;
    }
    if (consumed >= target * 0.95) {
      return AppColors.positive;
    }
    return AppColors.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final stateColor = _resolveColor();

    final isExceeded = !isProtein && (consumed > target * 1.05);
    final isTargetMet = isProtein
        ? consumed >= target
        : (consumed >= target * 0.95 && consumed <= target * 1.05);

    final String statusLabel;
    if (isExceeded) {
      statusLabel = '${(consumed - target).toStringAsFixed(0)}$unit over';
    } else if (isTargetMet) {
      statusLabel = isProtein && consumed > target
          ? '+${(consumed - target).toStringAsFixed(0)}$unit surplus'
          : 'Goal reached';
    } else {
      final remaining = (target - consumed).clamp(0.0, target);
      statusLabel = '${remaining.toStringAsFixed(0)}$unit left';
    }

    return Container(
      padding: const EdgeInsets.all(14),
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
              Text(
                name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                consumed.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                ' / ${target.toInt()}$unit',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.cardElevated,
              valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isTargetMet || isExceeded ? stateColor : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
