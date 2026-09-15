import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

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
        content: Text('Weekly report copied to clipboard! 📋'),
        backgroundColor: AppColors.positive,
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
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.positive),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Generating your weekly recomp report...',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.positive.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_outlined, color: AppColors.positive, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Recomp Digest ($week)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Nutrition · Training · Body Signal',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary, size: 18),
                    tooltip: 'Share Report',
                    onPressed: () => _copyToClipboard(content),
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ],
              ),

              if (_isExpanded) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.positive),
            ),
            SizedBox(width: 14),
            Text(
              'Loading weekly digest...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
