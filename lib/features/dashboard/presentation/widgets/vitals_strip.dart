import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class VitalsStrip extends StatelessWidget {
  final int waterMl;
  final int waterTargetMl;
  final int steps;
  final int stepsTarget;
  final ValueChanged<int> onAddWater;
  final VoidCallback onStepsTap;

  const VitalsStrip({
    super.key,
    required this.waterMl,
    required this.waterTargetMl,
    required this.steps,
    required this.stepsTarget,
    required this.onAddWater,
    required this.onStepsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VitalCard(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFF60A5FA),
            label: 'Hydration',
            value: waterMl,
            target: waterTargetMl,
            unit: 'ml',
            ctaLabel: '+ 250 ml',
            onTap: () => onAddWater(250),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _VitalCard(
            icon: Icons.directions_walk_rounded,
            iconColor: const Color(0xFF34D399),
            label: 'Steps',
            value: steps,
            target: stepsTarget,
            unit: '',
            ctaLabel: 'Details',
            onTap: onStepsTap,
          ),
        ),
      ],
    );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int value;
  final int target;
  final String unit;
  final String ctaLabel;
  final VoidCallback onTap;

  const _VitalCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    required this.ctaLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final met = progress >= 1.0;
    final barColor = met ? AppColors.positive : iconColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$value',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '/ $target${unit.isNotEmpty ? ' $unit' : ''}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.cardElevated,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ctaLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: barColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
