import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StepsCard extends StatelessWidget {
  final int currentSteps;
  final int targetSteps;
  final VoidCallback onSimulateStepAdd;
  final VoidCallback? onTap;

  const StepsCard({
    super.key,
    required this.currentSteps,
    required this.targetSteps,
    required this.onSimulateStepAdd,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = targetSteps > 0 ? (currentSteps / targetSteps).clamp(0.0, 1.0) : 0.0;
    final km = (currentSteps * 0.00078).toStringAsFixed(1);
    final kcal = (currentSteps * 0.04).round();

    return InkWell(
      onTap: onTap,
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
              Row(
                children: [
                  Icon(
                    Icons.directions_walk_rounded,
                    color: progress >= 1.0 ? AppColors.positive : AppColors.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Steps & Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: onSimulateStepAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text(
                    '+1,000 steps',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$currentSteps',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        ' / $targetSteps steps',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '~$km km · ~$kcal kcal burned',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.cardElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? AppColors.positive : AppColors.textPrimary,
                      ),
                      strokeWidth: 5,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

