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
          const Text(
            'MACROS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          // Protein — full width hero row
          _MacroRow(
            name: 'Protein',
            consumed: proteinConsumed,
            target: proteinTarget,
            unit: 'g',
            isProtein: true,
            accentColor: AppColors.brandPrimary,
          ),
          const SizedBox(height: 14),
          // Carbs + Fat side by side
          Row(
            children: [
              Expanded(
                child: _MacroRow(
                  name: 'Carbs',
                  consumed: carbsConsumed,
                  target: carbsTarget,
                  unit: 'g',
                  accentColor: const Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MacroRow(
                  name: 'Fat',
                  consumed: fatConsumed,
                  target: fatTarget,
                  unit: 'g',
                  accentColor: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Fiber
          _MacroRow(
            name: 'Fiber',
            consumed: fiberConsumed,
            target: fiberTarget,
            unit: 'g',
            accentColor: const Color(0xFF34D399),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String name;
  final double consumed;
  final double target;
  final String unit;
  final Color accentColor;
  final bool isProtein;

  const _MacroRow({
    required this.name,
    required this.consumed,
    required this.target,
    required this.unit,
    required this.accentColor,
    this.isProtein = false,
  });

  Color _resolveColor() {
    if (target <= 0) return accentColor;
    if (isProtein) {
      return consumed >= target ? AppColors.positive : accentColor;
    }
    if (consumed > target * 1.05) return AppColors.attention;
    if (consumed >= target * 0.95) return AppColors.positive;
    return accentColor;
  }

  String _statusLabel() {
    if (target <= 0) return '';
    final isExceeded = !isProtein && consumed > target * 1.05;
    final isMet = isProtein
        ? consumed >= target
        : (consumed >= target * 0.95 && consumed <= target * 1.05);
    if (isExceeded) {
      return '+${(consumed - target).toStringAsFixed(0)}$unit over';
    } else if (isMet) {
      return isProtein && consumed > target
          ? '+${(consumed - target).toStringAsFixed(0)}$unit surplus'
          : '✓ Goal';
    }
    final rem = (target - consumed).clamp(0.0, target);
    return '${rem.toStringAsFixed(0)}$unit left';
  }

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
    final resolvedColor = _resolveColor();
    final statusLabel = _statusLabel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: resolvedColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: consumed.toStringAsFixed(isProtein ? 1 : 0),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${target.toInt()}$unit',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.cardElevated,
            valueColor: AlwaysStoppedAnimation<Color>(resolvedColor),
            minHeight: isProtein ? 7 : 5,
          ),
        ),
        if (statusLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: resolvedColor == accentColor
                  ? AppColors.textMuted
                  : resolvedColor,
            ),
          ),
        ],
      ],
    );
  }
}
