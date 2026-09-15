import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum RestTimerState { idle, running, paused, done }

class SetRestTimerNotifier extends StateNotifier<({RestTimerState status, int remaining, int total})> {
  SetRestTimerNotifier() : super((status: RestTimerState.idle, remaining: 0, total: 0));

  Timer? _ticker;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const _defaults = {
    'compound':   180,
    'accessory':  90,
    'bodyweight': 120,
    'hiit':       30,
    'core':       60,
  };

  void startFor(String exerciseCategory, {int? overrideSeconds}) {
    _ticker?.cancel();
    final total = overrideSeconds ?? _defaults[exerciseCategory] ?? 90;
    state = (status: RestTimerState.running, remaining: total, total: total);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (state.status != RestTimerState.running) return;
    _ticker?.cancel();
    state = (status: RestTimerState.paused, remaining: state.remaining, total: state.total);
  }

  void resume() {
    if (state.status != RestTimerState.paused) return;
    state = (status: RestTimerState.running, remaining: state.remaining, total: state.total);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void dismiss() {
    _ticker?.cancel();
    state = (status: RestTimerState.idle, remaining: 0, total: 0);
  }

  void _tick() {
    if (state.status != RestTimerState.running) return;
    final next = state.remaining - 1;
    if (next <= 0) {
      _ticker?.cancel();
      state = (status: RestTimerState.done, remaining: 0, total: state.total);
      _fireNotification();
      return;
    }
    state = (status: RestTimerState.running, remaining: next, total: state.total);
  }

  Future<void> _fireNotification() async {
    try {
      await _plugin.show(
        300,
        'Rest Over',
        'Start your next set.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'set_rest_timer', 'Set Rest Timer',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final setRestTimerProvider =
    StateNotifierProvider<SetRestTimerNotifier,
        ({RestTimerState status, int remaining, int total})>(
      (ref) => SetRestTimerNotifier(),
    );
