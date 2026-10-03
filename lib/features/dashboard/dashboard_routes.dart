import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/dashboard/dashboard_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the dashboard feature.
final List<RouteBase> dashboardRoutes = [
  GoRoute(
    path: AppRoutes.dashboard,
    builder: (context, state) => const DashboardScreen(),
  ),
];
