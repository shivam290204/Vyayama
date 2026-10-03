import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/presentation/health_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes owned by the health profile feature.
final List<RouteBase> healthProfileRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.health,
    builder: (context, state) => const HealthScreen(),
  ),
];
