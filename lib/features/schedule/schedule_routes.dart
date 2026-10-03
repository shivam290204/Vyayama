import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/schedule/schedule_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the schedule feature.
final List<RouteBase> scheduleRoutes = [
  GoRoute(
    path: AppRoutes.schedule,
    builder: (context, state) => const ScheduleScreen(),
  ),
];
