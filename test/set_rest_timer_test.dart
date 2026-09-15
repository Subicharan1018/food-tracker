import 'package:flutter_test/flutter_test.dart';
import 'package:food_tracker/features/workouts/set_timer/set_rest_timer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SetRestTimerNotifier Tests', () {
    late SetRestTimerNotifier notifier;

    setUp(() {
      notifier = SetRestTimerNotifier();
    });

    tearDown(() {
      notifier.dispose();
    });

    test('Initial state is idle with 0 remaining', () {
      expect(notifier.state.status, RestTimerState.idle);
      expect(notifier.state.remaining, 0);
    });

    test('startFor assigns correct default rest durations by category', () {
      notifier.startFor('compound');
      expect(notifier.state.status, RestTimerState.running);
      expect(notifier.state.remaining, 180);
      expect(notifier.state.total, 180);

      notifier.startFor('accessory');
      expect(notifier.state.remaining, 90);

      notifier.startFor('bodyweight');
      expect(notifier.state.remaining, 120);

      notifier.startFor('hiit');
      expect(notifier.state.remaining, 30);

      notifier.startFor('core');
      expect(notifier.state.remaining, 60);
    });

    test('startFor respects custom overrideSeconds', () {
      notifier.startFor('compound', overrideSeconds: 240);
      expect(notifier.state.remaining, 240);
      expect(notifier.state.total, 240);
    });

    test('pause, resume, and dismiss correctly alter state', () {
      notifier.startFor('accessory', overrideSeconds: 60);
      expect(notifier.state.status, RestTimerState.running);

      notifier.pause();
      expect(notifier.state.status, RestTimerState.paused);
      expect(notifier.state.remaining, 60);

      notifier.resume();
      expect(notifier.state.status, RestTimerState.running);

      notifier.dismiss();
      expect(notifier.state.status, RestTimerState.idle);
      expect(notifier.state.remaining, 0);
    });
  });
}
