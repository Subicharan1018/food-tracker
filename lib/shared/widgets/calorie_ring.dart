import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CalorieRing extends StatefulWidget {
  final int targetCalories;
  final int consumedCalories;
  final int burnedCalories;
  final double size;

  const CalorieRing({
    super.key,
    required this.targetCalories,
    required this.consumedCalories,
    this.burnedCalories = 0,
    this.size = 200,
  });

  @override
  State<CalorieRing> createState() => _CalorieRingState();
}

class _CalorieRingState extends State<CalorieRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnim;
  double _prevProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final target = _calcProgress();
    _prevProgress = 0;
    _progressAnim = Tween(begin: 0.0, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CalorieRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumedCalories != widget.consumedCalories ||
        oldWidget.burnedCalories != widget.burnedCalories ||
        oldWidget.targetCalories != widget.targetCalories) {
      final newTarget = _calcProgress();
      _progressAnim =
          Tween(begin: _prevProgress, end: newTarget).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _prevProgress = newTarget;
      _controller
        ..reset()
        ..forward();
    }
  }

  double _calcProgress() {
    if (widget.targetCalories <= 0) return 0;
    return (widget.consumedCalories / widget.targetCalories).clamp(0.0, 1.5);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        widget.targetCalories - widget.consumedCalories + widget.burnedCalories;
    final isOver = widget.targetCalories > 0 &&
        widget.consumedCalories > (widget.targetCalories * 1.05);
    final isOnTrack = widget.targetCalories > 0 &&
        widget.consumedCalories >= (widget.targetCalories * 0.95) &&
        widget.consumedCalories <= (widget.targetCalories * 1.05);

    final Color ringColor = isOver
        ? AppColors.attention
        : (isOnTrack ? AppColors.positive : AppColors.brandPrimary);

    final String label = isOver
        ? 'over budget'
        : (isOnTrack ? 'on track ✓' : 'remaining');

    final Color labelColor = isOver
        ? AppColors.attention
        : (isOnTrack ? AppColors.positive : AppColors.textSecondary);

    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, _) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow behind ring
              if (!isOver && isOnTrack)
                Container(
                  width: widget.size * 0.82,
                  height: widget.size * 0.82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.positive.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(
                  progress: _progressAnim.value.clamp(0.0, 1.0),
                  ringColor: ringColor,
                  trackColor: AppColors.border.withValues(alpha: 0.5),
                  strokeWidth: 18,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${remaining.abs()}',
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.0,
                      color: isOver
                          ? AppColors.attention
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'kcal $label',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${widget.consumedCalories}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          ' / ${widget.targetCalories}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
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
      },
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

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Gradient arc
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + sweepAngle + 0.001,
      colors: [
        ringColor.withValues(alpha: 0.7),
        ringColor,
      ],
      tileMode: TileMode.clamp,
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.trackColor != trackColor;
}
