import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/scoreboard.dart';

String calculateIsoWeek([DateTime? date]) {
  final now = date ?? DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);
  final weekNum = ((now.difference(startOfYear).inDays + startOfYear.weekday) / 7).ceil();
  return '${now.year}-W${weekNum.toString().padLeft(2, '0')}';
}

class WeeklyDigestCard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? weekOverride;
  final VoidCallback? onDismiss;

  const WeeklyDigestCard({
    super.key,
    this.initialData,
    this.weekOverride,
    this.onDismiss,
  });

  @override
  ConsumerState<WeeklyDigestCard> createState() => _WeeklyDigestCardState();
}

class _WeeklyDigestCardState extends ConsumerState<WeeklyDigestCard> {
  bool _isExpanded = true;

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Weekly report copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isSundayOrMonday = now.weekday == DateTime.sunday || now.weekday == DateTime.monday;

    // In testing or when forced via props, allow display
    if (!isSundayOrMonday && widget.initialData == null && widget.weekOverride == null) {
      return const SizedBox.shrink();
    }

    final week = widget.weekOverride ?? calculateIsoWeek(now);
    final digestAsync = widget.initialData != null
        ? AsyncValue.data(widget.initialData)
        : ref.watch(weeklyDigestProvider(week));

    return digestAsync.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();

        final cached = data['cached'] == true;
        final content = data['content']?.toString() ?? '';

        if (!cached && content.isEmpty) {
          // If Sunday after 6:30 AM, show generating indicator
          final isSundayMorning = now.weekday == DateTime.sunday &&
              (now.hour > 6 || (now.hour == 6 && now.minute >= 30));

          if (isSundayMorning) {
            return Board(label: 'Weekly digest', child: Text('Generating your weekly recomp report…', style: AppTypography.bodyMedium));
          }
          return const SizedBox.shrink();
        }

        return Board(
          label: 'Weekly digest · $week',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy report',
                color: AppColors.textSecondary,
                onPressed: () => _copyToClipboard(content),
              ),
              IconButton(
                tooltip: _isExpanded ? 'Collapse' : 'Expand',
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 20),
                color: AppColors.textSecondary,
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
              ),
            ],
          ),
          child: _isExpanded
              ? Text(content, style: AppTypography.bodyLarge)
              : Text('Nutrition · training · body signal', style: AppTypography.bodyMedium),
        );
      },
      loading: () => Board(label: 'Weekly digest', child: Text('Loading weekly digest…', style: AppTypography.bodyMedium)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
