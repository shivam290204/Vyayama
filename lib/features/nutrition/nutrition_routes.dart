import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/nutrition/presentation/nutrition_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes owned by the nutrition feature.
final List<RouteBase> nutritionRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.nutrition,
    builder: (context, state) => const NutritionScreen(),
  ),
];
