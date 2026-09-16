import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class WorkoutProgressionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;
  final VoidCallback? onDismiss;

  const WorkoutProgressionCard({
    super.key,
    this.data,
    this.onDismiss,
  });

  @override
  ConsumerState<WorkoutProgressionCard> createState() => _WorkoutProgressionCardState();
}

class _WorkoutProgressionCardState extends ConsumerState<WorkoutProgressionCard> {
  final Set<String> _expandedExercises = {};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (widget.data == null && now.weekday != DateTime.saturday && now.weekday != DateTime.sunday) {
      return const SizedBox.shrink();
    }
    final userAsync = ref.watch(userProfileProvider);
    final userId = userAsync.value?.id ?? 'default_user';

    // If explicit data was not passed, watch provider
    final progressionAsync = widget.data != null
        ? AsyncValue.data(widget.data!)
        : ref.watch(workoutProgressionProvider(userId));

    return progressionAsync.when(
      data: (data) {
        final exercises = (data['exercises'] as List<dynamic>?) ?? [];
        if (exercises.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.attention.withValues(alpha: 0.35)),
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
                      color: AppColors.attention.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.trending_up_rounded, color: AppColors.attention, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Week Progression Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'AI Compound Lift Overload Targets',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
                      onPressed: widget.onDismiss,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              ...exercises.map((rawEx) {
                final ex = rawEx is Map<String, dynamic> ? rawEx : (rawEx as dynamic).toJson();
                final name = ex['name']?.toString() ?? 'Exercise';
                final current = ex['current']?.toString() ?? '—';
                final recommendation = ex['recommendation']?.toString() ?? '—';
                final reasoning = ex['reasoning']?.toString() ?? '';
                final isExpanded = _expandedExercises.contains(name);

                return InkWell(
                  onTap: reasoning.isNotEmpty
                      ? () {
                          setState(() {
                            if (isExpanded) {
                              _expandedExercises.remove(name);
                            } else {
                              _expandedExercises.add(name);
                            }
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ),
                            if (reasoning.isNotEmpty)
                              Icon(
                                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(child: Text(current, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.attention)),
                            Flexible(child: Text(recommendation, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.attention))),
                          ],
                        ),
                        if (isExpanded && reasoning.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            reasoning,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
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
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.attention),
            ),
            SizedBox(width: 14),
            Text(
              'Analyzing training progression...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
