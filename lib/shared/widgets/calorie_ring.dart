import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CalorieRing extends StatelessWidget {
  final int targetCalories;
  final int consumedCalories;
  final int burnedCalories;
  final double size;

  const CalorieRing({
    super.key,
    required this.targetCalories,
    required this.consumedCalories,
    this.burnedCalories = 0,
    this.size = 210,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = targetCalories - consumedCalories + burnedCalories;
    final progress = targetCalories > 0
        ? (consumedCalories / targetCalories).clamp(0.0, 1.5)
        : 0.0;
    final isOver = remaining < 0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              ringColor: isOver ? AppColors.coral : AppColors.emerald,
              trackColor: AppColors.cardElevated,
              strokeWidth: 16,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${remaining.abs()}',
                style: AppTypography.displayLarge.copyWith(
                  color: isOver ? AppColors.coral : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 38,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isOver ? 'kcal over' : 'kcal remaining',
                style: AppTypography.labelSmall.copyWith(
                  color: isOver ? AppColors.coral : AppColors.emeraldLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$consumedCalories',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      ' / ',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    Text(
                      '$targetCalories target',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start from top (-pi / 2)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.trackColor != trackColor;
}
