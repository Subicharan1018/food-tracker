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
                color: AppColors.coral,
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroCard(
                name: 'Carbs',
                consumed: carbsConsumed,
                target: carbsTarget,
                unit: 'g',
                color: AppColors.amber,
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
                color: AppColors.violet,
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
                color: AppColors.teal,
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
  final Color color;
  final IconData icon;

  const _MacroCard({
    required this.name,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final remaining = (target - consumed).clamp(0.0, target);

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
              Icon(icon, size: 16, color: color),
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
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${remaining.toStringAsFixed(0)}$unit left',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: remaining == 0 ? color : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
