import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/challenges/challenges_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the challenges feature.
final List<RouteBase> challengesRoutes = [
  GoRoute(
    path: AppRoutes.challenges,
    builder: (context, state) => const ChallengesScreen(),
  ),
];
