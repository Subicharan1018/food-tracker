import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/theme/app_theme.dart';
import 'set_rest_timer_service.dart';

class SetRestTimerWidget extends ConsumerStatefulWidget {
  const SetRestTimerWidget({super.key});

  @override
  ConsumerState<SetRestTimerWidget> createState() => _SetRestTimerWidgetState();
}

class _SetRestTimerWidgetState extends ConsumerState<SetRestTimerWidget> {
  final AudioPlayer _dingPlayer = AudioPlayer();
  bool _playedDingForDone = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _dingPlayer.setAsset('assets/audio/ding.wav');
    } catch (_) {}
  }

  @override
  void dispose() {
    _dingPlayer.dispose();
    super.dispose();
  }

  void _showAdjustDurationSheet(BuildContext context, int currentRemaining, int currentTotal) {
    double sliderValue = (currentTotal > 0 ? currentTotal : 90).toDouble().clamp(30.0, 300.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Adjust Rest Duration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${sliderValue.round()} seconds',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.attention,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: sliderValue,
                    min: 30,
                    max: 300,
                    divisions: 18, // (300 - 30) / 15 = 18 steps
                    activeColor: AppColors.attention,
                    inactiveColor: AppColors.surfaceElevated,
                    onChanged: (val) {
                      setModalState(() => sliderValue = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.positive,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        ref.read(setRestTimerProvider.notifier).startFor(
                              'custom',
                              overrideSeconds: sliderValue.round(),
                            );
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Set Rest Timer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(setRestTimerProvider);
    final notifier = ref.read(setRestTimerProvider.notifier);

    if (timerState.status == RestTimerState.idle) {
      return const SizedBox.shrink();
    }

    if (timerState.status == RestTimerState.done) {
      if (!_playedDingForDone) {
        _playedDingForDone = true;
        _dingPlayer.seek(Duration.zero).then((_) => _dingPlayer.play());
      }
    } else {
      _playedDingForDone = false;
    }

    final isDone = timerState.status == RestTimerState.done;
    final total = timerState.total > 0 ? timerState.total : 1;
    final progress = isDone ? 1.0 : (timerState.remaining / total).clamp(0.0, 1.0);
    final isLowTime = !isDone && timerState.remaining <= 10;

    final ringColor = isDone
        ? AppColors.positive
        : (isLowTime ? const Color(0xFFEF4444) : AppColors.attention);

    final mins = (timerState.remaining ~/ 60).toString().padLeft(2, '0');
    final secs = (timerState.remaining % 60).toString().padLeft(2, '0');
    final timeDisplay = isDone ? 'GO!' : '$mins:$secs';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ringColor.withValues(alpha: isLowTime ? 0.8 : 0.3),
          width: isLowTime ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Circular Countdown Indicator with Long Press gesture
          GestureDetector(
            onLongPress: () => _showAdjustDurationSheet(context, timerState.remaining, timerState.total),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4.5,
                    backgroundColor: AppColors.surfaceElevated,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    strokeCap: StrokeCap.round,
                  ),
                  Icon(
                    isDone ? Icons.check_rounded : Icons.timer_outlined,
                    color: ringColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Label & Time Display
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isDone ? 'REST COMPLETE' : 'REST PERIOD',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: ringColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '• Press & hold to adjust',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  timeDisplay,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Dismiss Button
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
            onPressed: () => notifier.dismiss(),
          ),
        ],
      ),
    );
  }
}
