/// Returns the meal slot that should be focused when the dashboard opens.
///
/// These are focus windows, not restrictions: users can still tap any other
/// meal in the rail and log it manually.
String mealSlotForTime(DateTime time) {
  final minutes = time.hour * 60 + time.minute;
  if (minutes < 11 * 60) return 'breakfast';
  if (minutes < 16 * 60) return 'lunch';
  if (minutes < 17 * 60 + 30) return 'shake';
  if (minutes < 19 * 60 + 30) return 'pre_workout';
  return 'dinner';
}
