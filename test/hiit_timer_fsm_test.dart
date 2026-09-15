import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/workouts/hiit/hiit_timer_engine.dart';

void main() {
  group('HiitTimerEngine FSM Tests', () {
    late HiitTimerEngine engine;
    final phaseChanges = <HiitPhase>[];

    setUp(() {
      phaseChanges.clear();
      engine = HiitTimerEngine();
      engine.onPhaseChange = (phase) => phaseChanges.add(phase);
    });

    tearDown(() {
      engine.dispose();
    });

    test('Initial state is idle with default rounds', () {
      expect(engine.state.phase, HiitPhase.idle);
      expect(engine.state.currentRound, 0);
      expect(engine.state.totalRounds, 6);
      expect(engine.state.secondsRemaining, 30);
    });

    test('Start initiates sprint phase with custom rounds', () {
      engine.start(totalRounds: 8);
      expect(engine.state.phase, HiitPhase.sprint);
      expect(engine.state.currentRound, 1);
      expect(engine.state.totalRounds, 8);
      expect(engine.state.secondsRemaining, 30);
      expect(phaseChanges, [HiitPhase.sprint]);
    });

    test('Pause and resume correctly preserve state and phase', () {
      engine.start(totalRounds: 6);
      expect(engine.state.phase, HiitPhase.sprint);

      engine.pause();
      expect(engine.state.phase, HiitPhase.paused);
      expect(engine.state.phaseBeforePause, HiitPhase.sprint);

      engine.resume();
      expect(engine.state.phase, HiitPhase.sprint);
    });

    test('Reset returns engine to initial idle state', () {
      engine.start(totalRounds: 6);
      engine.reset();
      expect(engine.state.phase, HiitPhase.idle);
      expect(engine.state.currentRound, 0);
    });
  });
}
