import 'package:fitbuddy/features/workouts/data/repository_providers.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:fitbuddy/features/workouts/state/workout_completed_notifier.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A workout counts as "completed today" (mascot, streaks) once at least
/// this share of its exercises is done. Anything with one finished exercise
/// is still saved to the log.
const double kCompletionThreshold = 0.5;

/// Holds the guided session state. The screen owns the 1-second timer and
/// calls [tick]; this class stays free of timers so it is easy to test.
class WorkoutSessionNotifier extends Notifier<SessionState> {
  String _planDayId = '';
  double _weightKg = 70;

  @override
  SessionState build() => const SessionState.empty();

  /// Starts a fresh session.
  void start(
    List<SessionItem> items, {
    required String planDayId,
    required double weightKg,
  }) {
    _planDayId = planDayId;
    _weightKg = weightKg;
    state = const SessionState.empty();
    _apply(SessionEngine.start(items));
  }

  void tick() => _apply(SessionEngine.tick(state));
  void completeSet() => _apply(SessionEngine.completeSet(state));
  void skipRest() => _apply(SessionEngine.skipRest(state));
  void addRestTime([int seconds = 15]) =>
      _apply(SessionEngine.addRestTime(state, seconds));
  void next() => _apply(SessionEngine.next(state));
  void previous() => _apply(SessionEngine.previous(state));
  void togglePause() => _apply(SessionEngine.togglePause(state));
  void finishNow() => _apply(SessionEngine.finish(state));

  /// Clears the session without saving.
  void reset() => state = const SessionState.empty();

  void _apply(SessionState next) {
    if (next.isFinished && next.items.isNotEmpty && next.summary == null) {
      final summary = SessionEngine.summarize(next, _weightKg);
      state = next.copyWith(summary: summary);
      _persist(summary);
    } else {
      state = next;
    }
  }

  Future<void> _persist(SessionSummary summary) async {
    if (summary.exercisesCompleted == 0) return;
    if (summary.completionRatio >= kCompletionThreshold) {
      ref.read(workoutCompletedTodayProvider.notifier).markCompleted();
    }
    try {
      await ref.read(workoutLogRepositoryProvider).logWorkout(
            planDayId: _planDayId,
            durationMin: summary.durationMin,
            caloriesBurned: summary.calories,
          );
    } catch (e) {
      debugPrint('Could not save workout log: $e');
    }
  }
}

/// Guided session state.
final workoutSessionProvider =
    NotifierProvider<WorkoutSessionNotifier, SessionState>(
  WorkoutSessionNotifier.new,
);
