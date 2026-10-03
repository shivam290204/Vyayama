import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/home/home_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the home feature (`/home`).
final List<RouteBase> homeRoutes = [
  GoRoute(
    path: AppRoutes.home,
    builder: (context, state) => const HomeScreen(),
  ),
];
