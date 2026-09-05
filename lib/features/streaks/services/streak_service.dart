class StreakResult {
  final int currentCount;
  final int longestCount;
  final String lastActiveDate;
  final bool incremented;

  const StreakResult({
    required this.currentCount,
    required this.longestCount,
    required this.lastActiveDate,
    required this.incremented,
  });
}

class StreakEngine {
  /// Computes updated streak count given the current streak state and activity date.
  /// Dates are YYYY-MM-DD strings.
  static StreakResult processActivity({
    required int currentCount,
    required int longestCount,
    String? lastActiveDate,
    required DateTime today,
  }) {
    final todayStr = _formatDate(today);

    // If already active today, no change
    if (lastActiveDate == todayStr) {
      return StreakResult(
        currentCount: currentCount,
        longestCount: longestCount,
        lastActiveDate: todayStr,
        incremented: false,
      );
    }

    final yesterdayStr = _formatDate(today.subtract(const Duration(days: 1)));

    int newCurrent;
    if (lastActiveDate == yesterdayStr) {
      // Consecutive day!
      newCurrent = currentCount + 1;
    } else {
      // First activity or broke streak
      newCurrent = 1;
    }

    final newLongest = newCurrent > longestCount ? newCurrent : longestCount;

    return StreakResult(
      currentCount: newCurrent,
      longestCount: newLongest,
      lastActiveDate: todayStr,
      incremented: true,
    );
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
