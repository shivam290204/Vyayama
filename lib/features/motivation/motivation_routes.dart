import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/motivation/boost_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the Daily Boost feature (`/boost`).
final List<RouteBase> motivationRoutes = [
  GoRoute(
    path: AppRoutes.dailyBoost,
    builder: (context, state) => const BoostScreen(),
  ),
];
