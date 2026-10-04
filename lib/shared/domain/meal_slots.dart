/// The day's meal slots from the Recomp plan — one catalogue for every screen
/// (home schedule, log-food picker, macro-source filter).
class MealSlot {
  final String key;
  final String label;

  /// Planned time, or null for "anytime".
  final ({int hour, int minute})? time;

  const MealSlot(this.key, this.label, this.time);

  String get timeLabel {
    final t = time;
    if (t == null) return 'ANYTIME';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

const mealSlots = <MealSlot>[
  MealSlot('breakfast', 'Breakfast', (hour: 6, minute: 0)),
  MealSlot('lunch', 'Lunch', (hour: 13, minute: 0)),
  MealSlot('shake', 'Shake', (hour: 16, minute: 30)),
  MealSlot('pre_workout', 'Pre-workout', (hour: 18, minute: 0)),
  MealSlot('dinner', 'Dinner', (hour: 20, minute: 15)),
  MealSlot('snack', 'Snack', null),
];

MealSlot mealSlot(String key) => mealSlots.firstWhere((s) => s.key == key, orElse: () => MealSlot(key, key, null));
