class SnapStreakCalculator {
  /// Evaluates whether a streak is broken based on timezone-aware dates.
  static bool isStreakBroken(DateTime lastSnapDate, DateTime now) {
    // A streak is broken if the difference between now and the last snap date is more than 1 day
    final difference = now.difference(lastSnapDate).inDays;
    return difference > 1;
  }

  /// Calculates the current milestone.
  static int getMilestone(int streakCount) {
    final milestones = [100, 50, 30, 14, 7, 3];
    for (final m in milestones) {
      if (streakCount >= m) return m;
    }
    return 0;
  }
}
