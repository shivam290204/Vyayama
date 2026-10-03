import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/workouts/screens/exercise_detail_screen.dart';
import 'package:fitbuddy/features/workouts/screens/plan_builder_screen.dart';
import 'package:fitbuddy/features/workouts/screens/plan_detail_screen.dart';
import 'package:fitbuddy/features/workouts/screens/workout_session_screen.dart';
import 'package:fitbuddy/features/workouts/screens/workouts_home_screen.dart';
import 'package:go_router/go_router.dart';

/// All workout routes. Static paths come before parameterized ones.
final List<RouteBase> workoutsRoutes = [
  GoRoute(
    path: AppRoutes.workouts,
    builder: (context, state) => const WorkoutsHomeScreen(),
  ),
  GoRoute(
    path: AppRoutes.planBuilder,
    builder: (context, state) =>
        PlanBuilderScreen(planId: state.uri.queryParameters['planId']),
  ),
  GoRoute(
    path: AppRoutes.workoutPlan,
    builder: (context, state) =>
        PlanDetailScreen(planId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: AppRoutes.workoutSession,
    builder: (context, state) =>
        WorkoutSessionScreen(dayId: state.pathParameters['dayId']!),
  ),
  GoRoute(
    path: AppRoutes.exercise,
    builder: (context, state) =>
        ExerciseDetailScreen(exerciseId: state.pathParameters['id']!),
  ),
];
