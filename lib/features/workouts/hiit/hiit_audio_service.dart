import 'package:just_audio/just_audio.dart';
import 'hiit_timer_engine.dart';

class HiitAudioService {
  final _sprint = AudioPlayer();
  final _recovery = AudioPlayer();
  final _tick = AudioPlayer();
  final _bell = AudioPlayer();

  Future<void> init() async {
    try {
      await _sprint.setAsset('assets/audio/whistle_short.wav');
      await _recovery.setAsset('assets/audio/recovery_beep.wav');
      await _tick.setAsset('assets/audio/countdown_tick.wav');
      await _bell.setAsset('assets/audio/gym_bell.wav');
    } catch (_) {}
  }

  Future<void> playForPhase(HiitPhase phase) async {
    try {
      switch (phase) {
        case HiitPhase.sprint:
          await _sprint.seek(Duration.zero);
          await _sprint.play();
        case HiitPhase.recovery:
          await _recovery.seek(Duration.zero);
          await _recovery.play();
        case HiitPhase.sessionDone:
          for (var i = 0; i < 3; i++) {
            await _bell.seek(Duration.zero);
            await _bell.play();
            await Future.delayed(const Duration(milliseconds: 500));
          }
        default:
          break;
      }
    } catch (_) {}
  }

  Future<void> playCountdownTick() async {
    try {
      await _tick.seek(Duration.zero);
      await _tick.play();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await Future.wait([
        _sprint.dispose(),
        _recovery.dispose(),
        _tick.dispose(),
        _bell.dispose()
      ]);
    } catch (_) {}
  }
}
