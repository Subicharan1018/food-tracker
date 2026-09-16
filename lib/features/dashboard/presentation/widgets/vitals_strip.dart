import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// A compact home for the two passive, daily metrics.
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppShapes.information,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Vital(
              icon: Icons.water_drop_outlined,
              label: 'Hydration',
              value: '$waterMl',
              suffix: ' / $waterTargetMl ml',
              progress: waterTargetMl == 0 ? 0.0 : waterMl / waterTargetMl,
              onTap: () => onAddWater(250),
              action: '+250 ml',
            ),
          ),
          Container(width: 1, height: 86, color: AppColors.border),
          Expanded(
            child: _Vital(
              icon: Icons.directions_walk_rounded,
              label: 'Steps',
              value: '$steps',
              suffix: ' / $stepsTarget',
              progress: stepsTarget == 0 ? 0.0 : steps / stepsTarget,
              onTap: onStepsTap,
              action: 'Details',
            ),
          ),
        ],
      ),
    );
  }
}

class _Vital extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final double progress;
  final VoidCallback onTap;
  final String action;

  const _Vital({required this.icon, required this.label, required this.value, required this.suffix, required this.progress, required this.onTap, required this.action});

  @override
  Widget build(BuildContext context) {
    final met = progress >= 1;
    final colour = met ? AppColors.positive : AppColors.brandPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 17, color: colour), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary))]),
            const SizedBox(height: 8),
            RichText(text: TextSpan(children: [TextSpan(text: value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)), TextSpan(text: suffix, style: const TextStyle(fontSize: 10, color: AppColors.textMuted))])),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), minHeight: 5, backgroundColor: AppColors.cardElevated, valueColor: AlwaysStoppedAnimation(colour)),
            ),
            const SizedBox(height: 5),
            Text(action, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colour)),
          ],
        ),
      ),
    );
  }
}
