import '../../core/local_db/app_database.dart';

/// Your Recomp manual's progression rules, applied to logged sets.
///
/// | Hit top of rep range on all sets, 2 sessions in a row | +2 kg next session
/// | Bar maxed (26 kg) and reps still easy                 | 3-sec lowering → pause → extra set → single-limb
/// | Pull-ups: 4 × 10 strict                               | +2 kg backpack
/// | Push-ups: 3 × 25 easy                                 | decline → one-arm negative → archer
/// | 3+ weeks without strength progress                    | check sleep and calories first
///
/// "Form is rough" can't be seen in the numbers, so it's left to you.
class Progression {
  final String headline;
  final String detail;
  final bool isStall;
  const Progression(this.headline, this.detail, {this.isStall = false});
}

const smallestPlateKg = 2.0;
const barMaxKg = 26.0;

class _Target {
  final int sets;
  final int topReps;
  const _Target(this.sets, this.topReps);
}

/// "4 × 8–10" → 4 sets, top 10.  "3 × 12/leg" → 3 × 12.  Timed/AMRAP → null.
_Target? _parseTarget(String setsReps) {
  final m = RegExp(r'^(\d+)\s*[×x]\s*(\d+)(?:\s*[–-]\s*(\d+))?(?:/leg)?$').firstMatch(setsReps.trim());
  if (m == null) return null;
  return _Target(int.parse(m.group(1)!), int.parse(m.group(3) ?? m.group(2)!));
}

class _Session {
  final String date;
  final double weight;
  final List<int> reps;
  const _Session(this.date, this.weight, this.reps);
}

/// Sessions for one exercise, newest first, using each day's heaviest load.
List<_Session> _sessions(List<WorkoutSetLog> logs) {
  final byDate = <String, List<WorkoutSetLog>>{};
  for (final log in logs.where((l) => l.completed)) {
    byDate.putIfAbsent(log.date, () => []).add(log);
  }
  final sessions = byDate.entries.map((e) {
    final top = e.value.map((l) => l.weightKg).reduce((a, b) => a > b ? a : b);
    return _Session(e.key, top, [for (final l in e.value) if (l.weightKg == top) l.reps]);
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return sessions;
}

bool _hitTop(_Session s, _Target t) => s.reps.length >= t.sets && s.reps.where((r) => r >= t.topReps).length >= t.sets;

String _kg(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

Progression? recommendProgression({
  required String exercise,
  required String setsReps,
  required List<WorkoutSetLog> history,
  bool usesBar = false,
  double? averageSleepHours,
}) {
  final sessions = _sessions(history.where((l) => l.exerciseName == exercise).toList());
  if (sessions.isEmpty) return null;
  final last = sessions.first;
  final name = exercise.toLowerCase();

  // Bodyweight specials from the manual.
  if (name.startsWith('pull-up')) {
    final strictTens = last.reps.where((r) => r >= 10).length;
    return strictTens >= 4
        ? Progression('Add +${_kg(smallestPlateKg)} kg', '4 × 10 strict done — load a backpack (books or water bottles).')
        : Progression('Build to 4 × 10', 'Last time: ${last.reps.join('/')}. Add load once all four sets reach 10.');
  }
  if (name.startsWith('push-up')) {
    final easy25 = last.reps.where((r) => r >= 25).length;
    return easy25 >= 3
        ? const Progression('Make it harder', 'Feet on bench (decline) → one-arm negative → archer push-up.')
        : null;
  }

  final target = _parseTarget(setsReps);
  if (target == null) return null;

  final stall = _stall(sessions, target, averageSleepHours);
  if (stall != null) return stall;

  final twoInARow = sessions.length >= 2 &&
      sessions[1].weight == last.weight &&
      _hitTop(last, target) &&
      _hitTop(sessions[1], target);

  if (twoInARow) {
    final next = last.weight + smallestPlateKg;
    if (usesBar && next > barMaxKg) {
      return Progression(
        'Bar is maxed — slow it down',
        'Add a 3-sec lowering at ${_kg(last.weight)} kg. Then a 2-sec pause, then an extra set, then single-arm/leg.',
      );
    }
    return Progression('Go to ${_kg(next)} kg', '${target.sets} × ${target.topReps} hit two sessions running at ${_kg(last.weight)} kg.');
  }
  if (_hitTop(last, target)) {
    return Progression('Repeat ${_kg(last.weight)} kg', 'Top of the range once — do it again next session, then add load.');
  }
  return Progression(
    'Stay at ${_kg(last.weight)} kg',
    'Last time ${last.reps.join('/')} — aim for ${target.topReps} on all ${target.sets} sets.',
  );
}

Progression? _stall(List<_Session> sessions, _Target target, double? sleepHours) {
  // Any progress (more load, or more reps at the same load) inside 3 weeks?
  final newest = DateTime.parse(sessions.first.date);
  final window = sessions.where((s) => newest.difference(DateTime.parse(s.date)).inDays <= 21).toList();
  if (window.length < 3) return null;
  final oldest = window.last;
  if (newest.difference(DateTime.parse(oldest.date)).inDays < 21) return null;
  int volume(_Session s) => s.reps.fold(0, (a, b) => a + b);
  final progressed = window.any((s) => s.weight > oldest.weight || (s.weight == oldest.weight && volume(s) > volume(oldest)));
  if (progressed || _hitTop(sessions.first, target)) return null;
  final sleep = sleepHours == null
      ? 'Check sleep and calories first'
      : 'Sleep is averaging ${sleepHours.toStringAsFixed(1)} h — check that and calories first';
  return Progression('No progress in 3 weeks', '$sleep, then add one set to compound lifts.', isStall: true);
}
