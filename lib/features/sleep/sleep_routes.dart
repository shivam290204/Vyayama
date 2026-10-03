import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/sleep/presentation/sleep_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes owned by the sleep feature.
final List<RouteBase> sleepRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.sleep,
    builder: (context, state) => const SleepScreen(),
  ),
];
