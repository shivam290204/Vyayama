import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/workouts/data/mock_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/supabase_workout_log_repository.dart';
import 'package:fitbuddy/features/workouts/data/supabase_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_log_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides [SupabaseWorkoutRepository] when configured, falling back to mock.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseWorkoutRepository();
  }
  return MockWorkoutRepository();
});

/// Provides [SupabaseWorkoutLogRepository] when configured, falling back to mock.
final workoutLogRepositoryProvider = Provider<WorkoutLogRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    return SupabaseWorkoutLogRepository();
  }
  return MockWorkoutLogRepository();
});
