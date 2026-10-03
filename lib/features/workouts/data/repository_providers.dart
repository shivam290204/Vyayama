import 'package:fitbuddy/features/workouts/data/mock_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_log_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Override this with a Supabase-backed repository later.
final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => MockWorkoutRepository(),
);

/// Override this with a Supabase-backed repository later.
final workoutLogRepositoryProvider = Provider<WorkoutLogRepository>(
  (ref) => MockWorkoutLogRepository(),
);
