import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Scoreboard primitives. Screens compose these instead of hand-building
/// containers and text styles, so the look lives in one place.
///
///   Board      — a section opened by a heavy rule and a caps label.
///   BigNumber  — the one number a board is about.
///   StatLine   — label · value / target · segmented meter.
///   SegmentMeter — LED-style segmented progress.
///   ActionSheet  — the one bottom-sheet shape for every "edit / log" flow.

/// A section: heavy rule, caps label (+ optional trailing), then content.
/// Boards stack on the page with no boxes around them.
class Board extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const Board({
    super.key,
    required this.label,
    required this.child,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(AppShapes.gutter, 0, AppShapes.gutter, 28),
  });

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label.toUpperCase(), style: AppTypography.label)),
          ?trailing,
        ],
      ),
    );
    final body = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: AppShapes.ruleHeavy, thickness: AppShapes.ruleHeavy, color: AppColors.rule),
          header,
          child,
        ],
      ),
    );
    if (onTap == null) return body;
    return Semantics(button: true, child: InkWell(onTap: onTap, child: body));
  }
}

/// The headline figure: condensed numerals with a small unit/caption.
class BigNumber extends StatelessWidget {
  final String value;
  final String? unit;
  final String? caption;
  final Color? color;
  final TextStyle? style;

  const BigNumber(this.value, {super.key, this.unit, this.caption, this.color, this.style});

  @override
  Widget build(BuildContext context) {
    final big = (style ?? AppTypography.hero).copyWith(color: color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(child: Text(value, style: big, maxLines: 1, overflow: TextOverflow.fade, softWrap: false)),
            if (unit != null) ...[
              const SizedBox(width: 8),
              Text(unit!.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 18, color: AppColors.textSecondary)),
            ],
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: 8),
          Text(caption!, style: AppTypography.dataSmall),
        ],
      ],
    );
  }
}

/// LED-style segmented meter. Segments past [fraction] are dark; an overflow
/// (> 1) lights the whole bar in [overColor].
class SegmentMeter extends StatelessWidget {
  final double fraction;
  final Color color;
  final Color? overColor;
  final int segments;
  final double height;

  const SegmentMeter({
    super.key,
    required this.fraction,
    this.color = AppColors.textPrimary,
    this.overColor,
    this.segments = 24,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final f = fraction.isFinite ? fraction : 0.0;
    final over = f > 1 && overColor != null;
    final lit = (f.clamp(0.0, 1.0) * segments).round();
    return Semantics(
      value: '${(f * 100).round()}%',
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < segments; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: ColoredBox(
                  color: i < lit ? (over ? overColor! : color) : AppColors.surfaceElevated,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One measured quantity on a board: CAPS LABEL   value / target unit
///                                    [segmented meter]
class StatLine extends StatelessWidget {
  final String label;
  final num value;
  final num? target;
  final String unit;
  final Color color;
  final Color? overColor;
  final String? note;
  final int decimals;

  const StatLine({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.target,
    this.color = AppColors.textPrimary,
    this.overColor,
    this.note,
    this.decimals = 0,
  });

  String _fmt(num v) => v.toStringAsFixed(decimals);

  @override
  Widget build(BuildContext context) {
    final t = target;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(width: 96, child: Text(label.toUpperCase(), style: AppTypography.label.copyWith(color: AppColors.textPrimary))),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _fmt(value), style: AppTypography.data.copyWith(fontSize: 15)),
                    if (t != null) TextSpan(text: ' / ${_fmt(t)}', style: AppTypography.dataSmall),
                    TextSpan(text: ' $unit', style: AppTypography.dataSmall),
                  ]),
                ),
              ),
              if (note != null) Text(note!, style: AppTypography.dataSmall.copyWith(color: color)),
            ],
          ),
          if (t != null && t > 0) ...[
            const SizedBox(height: 6),
            SegmentMeter(fraction: value / t, color: color, overColor: overColor, height: 6),
          ],
        ],
      ),
    );
  }
}

/// The one bottom-sheet layout: caps title, optional subtitle, scrollable
/// body, and a single full-width primary action that shows progress.
class ActionSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final String actionLabel;
  final Future<bool> Function()? onAction;

  const ActionSheet({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.subtitle,
    this.onAction,
  });

  /// Shows the sheet; [onAction] returns true to close it.
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget body,
    required String actionLabel,
    Future<bool> Function()? onAction,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ActionSheet(title: title, subtitle: subtitle, body: body, actionLabel: actionLabel, onAction: onAction),
    );
  }

  @override
  State<ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<ActionSheet> {
  bool _busy = false;

  Future<void> _run() async {
    if (widget.onAction == null) return;
    setState(() => _busy = true);
    try {
      final close = await widget.onAction!();
      if (close && mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppShapes.gutter, 0, AppShapes.gutter, 16 + insets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title.toUpperCase(), style: AppTypography.titleLarge),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(widget.subtitle!, style: AppTypography.bodyMedium),
            ],
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: widget.body)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _busy || widget.onAction == null ? null : _run,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                    )
                  : Text(widget.actionLabel.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
