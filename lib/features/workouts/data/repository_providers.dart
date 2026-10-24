import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/features/workouts/data/mock_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/supabase_workout_log_repository.dart';
import 'package:fitbuddy/features/workouts/data/supabase_workout_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_log_repository.dart';
import 'package:fitbuddy/features/workouts/data/workout_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

/// Provides [SupabaseWorkoutRepository] when configured, falling back to mock.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    try {
      return SupabaseWorkoutRepository();
    } catch (e) {
      debugPrint('[workoutRepositoryProvider] Fallback: $e');
    }
  }
  return MockWorkoutRepository();
});

/// Provides [SupabaseWorkoutLogRepository] when configured, falling back to mock.
final workoutLogRepositoryProvider = Provider<WorkoutLogRepository>((ref) {
  if (Env.isSupabaseConfigured) {
    try {
      return SupabaseWorkoutLogRepository();
    } catch (e) {
      debugPrint('[workoutLogRepositoryProvider] Fallback: $e');
    }
  }
  return MockWorkoutLogRepository();
});
