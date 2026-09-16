import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/di/providers.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/theme/app_theme.dart';
import 'hiit_audio_service.dart';
import 'hiit_timer_engine.dart';

class HiitTimerScreen extends ConsumerStatefulWidget {
  const HiitTimerScreen({super.key});

  @override
  ConsumerState<HiitTimerScreen> createState() => _HiitTimerScreenState();
}

class _HiitTimerScreenState extends ConsumerState<HiitTimerScreen> {
  final HiitAudioService _audio = HiitAudioService();
  int _selectedTotalRounds = 6;
  int _lastTickPlayedAt = -1;

  @override
  void initState() {
    super.initState();
    _audio.init();
    final engine = ref.read(hiitTimerProvider.notifier);
    engine.onPhaseChange = (phase) {
      _audio.playForPhase(phase);
    };
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  String _formatSeconds(int totalSec) {
    final mins = (totalSec ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSec % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _logHiitWorkout(int elapsedSeconds, int totalRounds) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final durationMin = (elapsedSeconds / 60.0).ceil();
    // Estimated ~12-15 kcal/min for high intensity sprint intervals
    final calories = (durationMin * 13).toDouble();

    await db.into(db.workoutSessions).insert(
      WorkoutSessionsCompanion.insert(
        id: 'hiit_${now.millisecondsSinceEpoch}',
        activityName: 'Lower B + HIIT ($totalRounds rounds)',
        durationMin: durationMin,
        intensity: const Value('vigorous'),
        caloriesBurned: calories,
        source: const Value('routine'),
        date: dateStr,
        loggedAt: Value(now),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('HIIT Session logged successfully! 🔥'),
          backgroundColor: AppColors.positive,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hiitTimerProvider);
    final engine = ref.read(hiitTimerProvider.notifier);

    // Trigger tick sound at 5s remaining
    if (state.secondsRemaining == 5 && _lastTickPlayedAt != 5 &&
        (state.phase == HiitPhase.sprint || state.phase == HiitPhase.recovery)) {
      _lastTickPlayedAt = 5;
      _audio.playCountdownTick();
    } else if (state.secondsRemaining != 5) {
      _lastTickPlayedAt = -1;
    }

    final isSprint = state.phase == HiitPhase.sprint;
    final isRecovery = state.phase == HiitPhase.recovery;
    final isDone = state.phase == HiitPhase.sessionDone;
    final isPaused = state.phase == HiitPhase.paused;
    final isIdle = state.phase == HiitPhase.idle;
    final isRoundComplete = state.phase == HiitPhase.roundComplete;

    final progress = isDone || isIdle ? 1.0 : (state.secondsRemaining / 30.0).clamp(0.0, 1.0);
    final ringColor = isSprint
        ? const Color(0xFFEF4444)
        : (isRecovery
            ? const Color(0xFF14B8A6)
            : (isDone ? AppColors.positive : (isRoundComplete ? AppColors.attention : AppColors.brandPrimary)));

    String phaseText = 'READY';
    if (isSprint) phaseText = 'SPRINT';
    if (isRecovery) phaseText = 'RECOVER';
    if (state.phase == HiitPhase.roundComplete) phaseText = 'ROUND UP';
    if (isPaused) phaseText = 'PAUSED';
    if (isDone) phaseText = 'COMPLETED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('HIIT Sprint Engine'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Top round status
              if (!isIdle)
                Text(
                  'ROUND ${state.currentRound} / ${state.totalRounds}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.textPrimary,
                  ),
                )
              else
                const Text(
                  'SELECT INTERVAL ROUNDS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),

              const SizedBox(height: 24),

              // Round Selector when Idle
              if (isIdle) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [6, 7, 8, 10].map((rounds) {
                    final selected = _selectedTotalRounds == rounds;
                    return ChoiceChip(
                        label: Text('$rounds Rounds'),
                        selected: selected,
                        selectedColor: AppColors.brandPrimary,
                        backgroundColor: AppColors.card,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.textInverse : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(color: selected ? AppColors.brandPrimary : AppColors.border),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _selectedTotalRounds = rounds),
                      );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              if (!isIdle) ...[
                _RoundProgress(current: state.currentRound, total: state.totalRounds),
                const SizedBox(height: 12),
              ],

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: ringColor.withValues(alpha: 0.09),
                  borderRadius: AppShapes.information,
                  border: Border.all(color: ringColor.withValues(alpha: 0.30)),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isIdle ? '30 sec sprint  ·  30 sec recovery' : (isPaused ? 'Timer paused — recover your breathing' : (isDone ? 'Session complete' : (isSprint ? 'Push hard, stay controlled' : 'Recover and prepare for the next sprint'))),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Circular Countdown Ring
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 14,
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            phaseText,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.0,
                              color: ringColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isDone ? 'DONE' : '${state.secondsRemaining}s',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Next Phase Preview
              if ((isSprint || isRecovery) && state.secondsRemaining <= 10)
                Text(
                  'Next: ${isSprint ? "RECOVER" : "SPRINT"} in ${state.secondsRemaining}s',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.attention,
                  ),
                )
              else
                const SizedBox(height: 24),

              const SizedBox(height: 8),

              // Session Summary on Completion
              if (isDone) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                      borderRadius: AppShapes.information,
                    border: Border.all(color: AppColors.positive.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'HIIT Session Finished! 🔥',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.positive,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Completed ${state.totalRounds} rounds in ${_formatSeconds(state.totalElapsedSeconds)}',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      Text(
                        'Estimated Calories: ~${((state.totalElapsedSeconds / 60.0).ceil() * 13)} kcal',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_rounded, color: AppColors.textInverse),
                    label: const Text(
                      'Log Workout Session',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textInverse),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.textInverse,
                      shape: RoundedRectangleBorder(borderRadius: AppShapes.action),
                    ),
                    onPressed: () => _logHiitWorkout(state.totalElapsedSeconds, state.totalRounds),
                  ),
                ),
              ] else if (isIdle) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 28, color: AppColors.textInverse),
                    label: const Text(
                      'Start HIIT Session',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textInverse),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      foregroundColor: AppColors.textInverse,
                      shape: RoundedRectangleBorder(borderRadius: AppShapes.action),
                    ),
                    onPressed: () => engine.start(totalRounds: _selectedTotalRounds),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                          label: Text(isPaused ? 'Resume' : 'Pause'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            if (isPaused) {
                              engine.resume();
                            } else {
                              engine.pause();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: IconButton.outlined(
                        icon: const Icon(Icons.stop_rounded, color: Color(0xFFEF4444)),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          engine.reset();
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Total elapsed time indicator
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total Time: ${_formatSeconds(state.totalElapsedSeconds)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundProgress extends StatelessWidget {
  final int current;
  final int total;

  const _RoundProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (index) {
        final completed = index < current - 1;
        final active = index == current - 1;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: index == total - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: completed
                  ? AppColors.positive
                  : (active ? AppColors.brandPrimary : AppColors.surfaceElevated),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
