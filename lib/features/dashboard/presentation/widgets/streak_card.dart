import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StreaksCard extends StatelessWidget {
  final int loggingStreak;
  final int workoutStreak;

  const StreaksCard({
    super.key,
    required this.loggingStreak,
    required this.workoutStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StreakTile(
            title: 'Logging Streak',
            subtitle: 'Consistency',
            count: loggingStreak,
            unit: 'days',
            icon: Icons.local_fire_department_rounded,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StreakTile(
            title: 'Workout Streak',
            subtitle: 'Recomp Split',
            count: workoutStreak,
            unit: 'sessions',
            icon: Icons.bolt_rounded,
            color: AppColors.emerald,
          ),
        ),
      ],
    );
  }
}

class _StreakTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final String unit;
  final IconData icon;
  final Color color;

  const _StreakTile({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
