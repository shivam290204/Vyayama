import 'package:fitbuddy/features/workouts/data/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether a workout has been completed today. Antigravity can
/// connect [workoutCompletedTodayProvider] to the mascot mood engine.
class WorkoutCompletedNotifier extends Notifier<bool> {
  @override
  bool build() {
    _hydrate();
    return false;
  }

  Future<void> _hydrate() async {
    try {
      final done =
          await ref.read(workoutLogRepositoryProvider).hasWorkoutOn(DateTime.now());
      if (done) state = true;
    } catch (_) {
      // Keep the default (false) if the log cannot be read.
    }
  }

  /// Called by the guided session when a workout is completed.
  void markCompleted() => state = true;

  /// Re-reads today's logs. Call on app resume or after midnight.
  Future<void> refresh() async {
    try {
      state =
          await ref.read(workoutLogRepositoryProvider).hasWorkoutOn(DateTime.now());
    } catch (_) {
      // Ignore read errors.
    }
  }
}

/// True once the user has completed a workout today.
final workoutCompletedTodayProvider =
    NotifierProvider<WorkoutCompletedNotifier, bool>(
  WorkoutCompletedNotifier.new,
);
