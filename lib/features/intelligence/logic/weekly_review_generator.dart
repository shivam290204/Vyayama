import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/intelligence/domain/interfaces/adaptive_journey_interface.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';
import 'package:fitbuddy/features/workouts/data/workout_log.dart';

/// Pure Dart deterministic generator for weekly fitness reviews.
///
/// Implements [IWeeklyFitnessReviewGenerator] without server cron jobs,
/// external APIs, or LLM hallucination.
class WeeklyFitnessReviewGenerator implements IWeeklyFitnessReviewGenerator {
  const WeeklyFitnessReviewGenerator({
    required this.workoutLogs,
    required this.recentStats,
    this.recentFeedback = const [],
    this.targetWorkoutsPerWeek = 3,
  });

  final List<WorkoutLog> workoutLogs;
  final List<DailyStats> recentStats;
  final List<WorkoutDifficultyFeedback> recentFeedback;
  final int targetWorkoutsPerWeek;

  @override
  Future<WeeklyFitnessReview> generateWeeklyReview({
    required DateTime weekEnding,
  }) async {
    final start = weekEnding.subtract(const Duration(days: 7));

    // 1. Sift workout logs in the trailing 7 days
    final logsInWeek = workoutLogs.where((l) {
      final d = l.completedAt;
      return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
          (d.isBefore(weekEnding) || d.isAtSameMomentAs(weekEnding));
    }).toList();

    // 2. Sift daily stats in the trailing 7 days
    final statsInWeek = recentStats.where((s) {
      final d = s.date;
      return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
          (d.isBefore(weekEnding) || d.isAtSameMomentAs(weekEnding));
    }).toList();

    // 3. Sift feedback in the trailing 7 days
    final feedbackInWeek = recentFeedback.where((f) {
      final d = f.completedAt;
      return (d.isAfter(start) || d.isAtSameMomentAs(start)) &&
          (d.isBefore(weekEnding) || d.isAtSameMomentAs(weekEnding));
    }).toList();

    final completed = logsInWeek.length;
    final scheduled = targetWorkoutsPerWeek > 0 ? targetWorkoutsPerWeek : 3;

    var logMinutes = 0;
    for (final l in logsInWeek) {
      logMinutes += l.durationMin;
    }

    var statsMinutes = 0;
    var totalSteps = 0;
    for (final s in statsInWeek) {
      statsMinutes += s.activeMinutes;
      totalSteps += s.steps;
    }

    final totalActiveMinutes = logMinutes > 0 ? logMinutes : statsMinutes;
    final consistencyScore =
        ((completed / scheduled).clamp(0.0, 1.0) * 100).round();

    // Build celebrations
    final celebrations = <String>[];
    if (completed >= scheduled) {
      celebrations.add('Hit your weekly target of $scheduled workouts!');
    } else if (completed > 0) {
      celebrations.add('Completed $completed workouts this week.');
    }

    if (totalSteps >= 35000) {
      celebrations.add('High weekly activity: $totalSteps total steps.');
    }

    final tooHardCount = feedbackInWeek
        .where((f) => f.rating == WorkoutDifficultyRating.tooHard)
        .length;
    final justRightCount = feedbackInWeek
        .where((f) => f.rating == WorkoutDifficultyRating.justRight)
        .length;

    if (justRightCount > 0 && tooHardCount == 0) {
      celebrations.add('Tuned exertion well: $justRightCount session(s) felt just right.');
    }

    if (celebrations.isEmpty) {
      celebrations.add('Every week is a new opportunity to restart.');
    }

    // Build areas for improvement
    final areas = <String>[];
    if (completed < scheduled) {
      final diff = scheduled - completed;
      areas.add(
        'Missed $diff scheduled workout${diff > 1 ? 's' : ''}. Consider scheduling 15-minute quick sessions when time is tight.',
      );
    }
    if (tooHardCount > 0) {
      areas.add(
        '$tooHardCount session(s) felt too hard. Prioritize 7-8 hours of sleep and adequate hydration between sessions.',
      );
    }

    // Determine recommended focus
    final String nextFocus;
    if (tooHardCount > 0) {
      nextFocus =
          'Active Recovery: Focus on restorative stretching, foam rolling, and gentle walks.';
    } else if (consistencyScore >= 80) {
      nextFocus =
          'Progressive Overload: You built great consistency. Aim for +1 rep or slight weight progression next week.';
    } else if (consistencyScore < 50) {
      nextFocus =
          'Habit Rebuild: Start next week with a low-pressure, 15-minute workout to restore rhythm.';
    } else {
      nextFocus =
          'Form Consolidation: Maintain current volume and dial in clean movement execution.';
    }

    final adherenceSummary =
        'Completed $completed of $scheduled scheduled sessions ($consistencyScore% consistency).';

    return WeeklyFitnessReview(
      weekStartDate: start,
      weekEndDate: weekEnding,
      completedSessions: completed,
      scheduledSessions: scheduled,
      totalActiveMinutes: totalActiveMinutes,
      totalSteps: totalSteps,
      consistencyScore: consistencyScore,
      adherenceSummary: adherenceSummary,
      recommendedNextFocus: nextFocus,
      celebrations: celebrations,
      areasForImprovement: areas,
    );
  }
}

