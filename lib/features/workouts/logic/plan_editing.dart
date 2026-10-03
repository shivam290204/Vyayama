import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// A plan can use each weekday at most once.
const int kMaxPlanDays = 7;

int _tmpCounter = 0;
String _tmpId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_tmpCounter++}';

/// Pure editing helpers for the custom plan builder.
extension PlanEditing on WorkoutPlan {
  /// Adds a day on the first free weekday.
  WorkoutPlan addDay() {
    if (days.length >= kMaxPlanDays) return this;
    final used = days.map((d) => d.dayNumber).toSet();
    var n = 1;
    while (used.contains(n)) {
      n++;
    }
    final day = PlanDay(
      id: _tmpId('day'),
      dayNumber: n,
      name: 'Workout ${days.length + 1}',
      exercises: const [],
    );
    return copyWith(days: _sorted([...days, day]));
  }

  WorkoutPlan removeDay(String dayId) =>
      copyWith(days: days.where((d) => d.id != dayId).toList());

  WorkoutPlan renameDay(String dayId, String name) =>
      _mapDay(dayId, (d) => d.copyWith(name: name));

  /// Moves a day to [weekday] if that weekday is free.
  WorkoutPlan setDayNumber(String dayId, int weekday) {
    if (weekday < 1 || weekday > 7) return this;
    if (days.any((d) => d.id != dayId && d.dayNumber == weekday)) return this;
    return copyWith(
      days: _sorted([
        for (final d in days)
          d.id == dayId ? d.copyWith(dayNumber: weekday) : d,
      ]),
    );
  }

  /// Adds [exercise] with sensible defaults (timed for cardio and stretching).
  WorkoutPlan addExercise(String dayId, Exercise exercise) {
    final timed =
        exercise.muscleGroup == 'cardio' || exercise.muscleGroup == 'flexibility';
    return _mapDay(dayId, (d) {
      final pe = PlanExercise(
        id: _tmpId('pe'),
        exerciseId: exercise.id,
        sortOrder: d.exercises.length,
        sets: timed ? 2 : 3,
        reps: timed ? null : 10,
        durationSec: timed ? 30 : null,
        restSec: 45,
      );
      return d.copyWith(exercises: [...d.exercises, pe]);
    });
  }

  WorkoutPlan updateExercise(String dayId, PlanExercise updated) =>
      _mapDay(dayId, (d) {
        return d.copyWith(
          exercises: [
            for (final e in d.exercises) e.id == updated.id ? updated : e,
          ],
        );
      });

  WorkoutPlan removeExercise(String dayId, String planExerciseId) =>
      _mapDay(dayId, (d) {
        return d.copyWith(
          exercises: _reindex(
            d.exercises.where((e) => e.id != planExerciseId).toList(),
          ),
        );
      });

  /// [newIndex] follows Flutter's `ReorderableListView.onReorder` rules.
  WorkoutPlan reorderExercise(String dayId, int oldIndex, int newIndex) =>
      _mapDay(dayId, (d) {
        final list = [...d.exercises];
        if (oldIndex < 0 || oldIndex >= list.length) return d;
        var target = newIndex;
        if (oldIndex < newIndex) target -= 1;
        final moved = list.removeAt(oldIndex);
        list.insert(target.clamp(0, list.length).toInt(), moved);
        return d.copyWith(exercises: _reindex(list));
      });

  /// A user-facing reason the plan cannot be saved, or null when it is valid.
  String? get validationError {
    if (title.trim().isEmpty) return 'Give your plan a name.';
    if (days.isEmpty) return 'Add at least one workout day.';
    for (final d in days) {
      if (d.exercises.isEmpty) {
        return 'Add at least one exercise to "${d.name}".';
      }
    }
    return null;
  }

  WorkoutPlan _mapDay(String dayId, PlanDay Function(PlanDay day) change) {
    return copyWith(
      days: [for (final d in days) d.id == dayId ? change(d) : d],
    );
  }
}

List<PlanDay> _sorted(List<PlanDay> days) =>
    [...days]..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));

List<PlanExercise> _reindex(List<PlanExercise> list) => [
      for (var i = 0; i < list.length; i++) list[i].copyWith(sortOrder: i),
    ];
