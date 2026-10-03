import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

Exercise ex(
  String id,
  String group, {
  String equipment = 'none',
  List<String> contra = const [],
  double met = 3,
}) {
  return Exercise(
    id: id,
    name: id,
    muscleGroup: group,
    equipment: equipment,
    instructions: const ['step'],
    commonMistakes: const [],
    contraindications: contra,
    met: met,
  );
}

PlanExercise pe(
  String id,
  String exerciseId, {
  int sets = 3,
  int? reps = 10,
  int? duration,
  int rest = 45,
}) {
  return PlanExercise(
    id: id,
    exerciseId: exerciseId,
    sets: sets,
    reps: duration == null ? reps : null,
    durationSec: duration,
    restSec: rest,
  );
}

WorkoutPlan makePlan(
  List<List<PlanExercise>> days, {
  String id = 'p1',
  String goal = 'lose',
  String level = 'beginner',
  bool isSystem = true,
}) {
  return WorkoutPlan(
    id: id,
    title: id,
    goal: goal,
    level: level,
    isSystem: isSystem,
    days: [
      for (var i = 0; i < days.length; i++)
        PlanDay(
          id: '${id}_d${i + 1}',
          dayNumber: i + 1,
          name: 'Day ${i + 1}',
          exercises: days[i],
        ),
    ],
  );
}
