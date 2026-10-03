import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/onboarding/screens/onboarding_screen.dart';

/// Onboarding route (guarded by the router redirect).
final List<RouteBase> onboardingRoutes = [
  GoRoute(
    path: AppRoutes.onboarding,
    builder: (context, state) => const OnboardingScreen(),
  ),
];
