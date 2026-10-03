/// MET value used for rest periods inside a session (light activity).
const double kRestMet = 1.5;

/// Estimated calories: `MET × weight_kg × hours` (spec 9.1).
double estimateCalories({
  required double met,
  required double weightKg,
  required double durationMinutes,
}) {
  if (met <= 0 || weightKg <= 0 || durationMinutes <= 0) return 0;
  return met * weightKg * (durationMinutes / 60.0);
}

/// Calories for a whole session. Each exercise uses its own MET for the
/// seconds spent working; rest time uses [kRestMet].
int estimateSessionCalories({
  required Iterable<({double met, int seconds})> activeSegments,
  required int restSeconds,
  required double weightKg,
}) {
  var total = 0.0;
  for (final seg in activeSegments) {
    total += estimateCalories(
      met: seg.met,
      weightKg: weightKg,
      durationMinutes: seg.seconds / 60.0,
    );
  }
  total += estimateCalories(
    met: kRestMet,
    weightKg: weightKg,
    durationMinutes: restSeconds / 60.0,
  );
  return total.round();
}
