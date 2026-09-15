import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

enum HiitPhase { idle, sprint, recovery, roundComplete, sessionDone, paused }

class HiitState {
  final HiitPhase phase;
  final int currentRound;
  final int totalRounds;
  final int secondsRemaining;
  final HiitPhase? phaseBeforePause;
  final int totalElapsedSeconds;

  const HiitState({
    this.phase = HiitPhase.idle,
    this.currentRound = 0,
    this.totalRounds = 6,
    this.secondsRemaining = 30,
    this.phaseBeforePause,
    this.totalElapsedSeconds = 0,
  });

  HiitState copyWith({
    HiitPhase? phase,
    int? currentRound,
    int? totalRounds,
    int? secondsRemaining,
    HiitPhase? phaseBeforePause,
    int? totalElapsedSeconds,
  }) =>
      HiitState(
        phase: phase ?? this.phase,
        currentRound: currentRound ?? this.currentRound,
        totalRounds: totalRounds ?? this.totalRounds,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
        phaseBeforePause: phaseBeforePause ?? this.phaseBeforePause,
        totalElapsedSeconds: totalElapsedSeconds ?? this.totalElapsedSeconds,
      );
}

class HiitTimerEngine extends StateNotifier<HiitState> {
  HiitTimerEngine() : super(const HiitState());

  Timer? _ticker;
  Function(HiitPhase)? onPhaseChange; // Wired to HiitAudioService

  void start({int totalRounds = 6}) {
    _ticker?.cancel();
    state = HiitState(
      phase: HiitPhase.sprint,
      currentRound: 1,
      totalRounds: totalRounds,
      secondsRemaining: 30,
      totalElapsedSeconds: 0,
    );
    onPhaseChange?.call(HiitPhase.sprint);
    _startTicker();
  }

  void pause() {
    if (state.phase == HiitPhase.idle || state.phase == HiitPhase.sessionDone || state.phase == HiitPhase.paused) return;
    _ticker?.cancel();
    state = state.copyWith(
      phase: HiitPhase.paused,
      phaseBeforePause: state.phase,
    );
  }

  void resume() {
    if (state.phase != HiitPhase.paused) return;
    state = state.copyWith(phase: state.phaseBeforePause ?? HiitPhase.sprint);
    _startTicker();
  }

  void reset() {
    _ticker?.cancel();
    state = const HiitState();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.phase == HiitPhase.paused || state.phase == HiitPhase.idle) return;

    final newElapsed = state.totalElapsedSeconds + 1;

    if (state.secondsRemaining > 1) {
      state = state.copyWith(
        secondsRemaining: state.secondsRemaining - 1,
        totalElapsedSeconds: newElapsed,
      );
      return;
    }

    // Phase expired
    _ticker?.cancel();

    if (state.phase == HiitPhase.sprint) {
      state = state.copyWith(
        phase: HiitPhase.recovery,
        secondsRemaining: 30,
        totalElapsedSeconds: newElapsed,
      );
      onPhaseChange?.call(HiitPhase.recovery);
      _startTicker();
      return;
    }

    if (state.phase == HiitPhase.recovery) {
      final nextRound = state.currentRound + 1;

      if (nextRound > state.totalRounds) {
        state = state.copyWith(
          phase: HiitPhase.sessionDone,
          secondsRemaining: 0,
          totalElapsedSeconds: newElapsed,
        );
        onPhaseChange?.call(HiitPhase.sessionDone);
        return;
      }

      state = state.copyWith(
        phase: HiitPhase.roundComplete,
        currentRound: nextRound,
        secondsRemaining: 0,
        totalElapsedSeconds: newElapsed,
      );
      onPhaseChange?.call(HiitPhase.roundComplete);
      Future.delayed(const Duration(seconds: 1), () {
        if (state.phase != HiitPhase.roundComplete) return;
        state = state.copyWith(
          phase: HiitPhase.sprint,
          secondsRemaining: 30,
        );
        onPhaseChange?.call(HiitPhase.sprint);
        _startTicker();
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final hiitTimerProvider =
    StateNotifierProvider<HiitTimerEngine, HiitState>((ref) => HiitTimerEngine());
