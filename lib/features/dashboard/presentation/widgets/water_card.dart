import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class WaterTrackingCard extends StatelessWidget {
  final int currentMl;
  final int targetMl;
  final Function(int ml) onAddWater;

  const WaterTrackingCard({
    super.key,
    required this.currentMl,
    required this.targetMl,
    required this.onAddWater,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetMl > 0 ? (currentMl / targetMl).clamp(0.0, 1.0) : 0.0;
    final glasses = (currentMl / 250).floor();

    return Container(
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
              Row(
                children: const [
                  Icon(Icons.water_drop_rounded, color: AppColors.cyan, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Water & Hydration',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentMl',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        ' / $targetMl ml',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$glasses glasses (250ml)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _QuickWaterButton(
                    label: '+250 ml',
                    onTap: () => onAddWater(250),
                  ),
                  const SizedBox(width: 8),
                  _QuickWaterButton(
                    label: '+500 ml',
                    onTap: () => onAddWater(500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.cardElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickWaterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickWaterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cyan.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.cyan,
          ),
        ),
      ),
    );
  }
}
