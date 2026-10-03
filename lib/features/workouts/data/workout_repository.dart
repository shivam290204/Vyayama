import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// Source of exercises and workout plans. Antigravity swaps the mock for a
/// Supabase implementation.
abstract class WorkoutRepository {
  /// All library exercises.
  Future<List<Exercise>> getExercises();

  /// Plans with `is_system = true`.
  Future<List<WorkoutPlan>> getSystemPlans();

  /// Custom plans owned by the signed-in user.
  Future<List<WorkoutPlan>> getMyPlans();

  /// A system or custom plan by id, or null.
  Future<WorkoutPlan?> getPlan(String id);

  /// The plan that contains the day [dayId], or null.
  Future<WorkoutPlan?> getPlanByDayId(String dayId);

  /// Creates or updates a custom plan. Always stored with `is_system = false`.
  Future<WorkoutPlan> savePlan(WorkoutPlan plan);

  /// Deletes a custom plan.
  Future<void> deletePlan(String id);
}
