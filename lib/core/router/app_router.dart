import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/router/app_shell.dart';
import 'package:fitbuddy/core/router/route_error_screen.dart';
import 'package:fitbuddy/features/auth/auth_routes.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/challenges/challenges_routes.dart';
import 'package:fitbuddy/features/dashboard/dashboard_routes.dart';
import 'package:fitbuddy/features/health_profile/health_profile_routes.dart';
import 'package:fitbuddy/features/home/home_routes.dart';
import 'package:fitbuddy/features/motivation/motivation_routes.dart';
import 'package:fitbuddy/features/nutrition/nutrition_routes.dart';
import 'package:fitbuddy/features/onboarding/onboarding_routes.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/profile_routes.dart';
import 'package:fitbuddy/features/schedule/schedule_routes.dart';
import 'package:fitbuddy/features/settings/settings_routes.dart';
import 'package:fitbuddy/features/sleep/sleep_routes.dart';
import 'package:fitbuddy/features/teams/teams_routes.dart';
import 'package:fitbuddy/features/workouts/workouts_routes.dart';
import 'package:fitbuddy/features/friends/friends_routes.dart';
import 'package:fitbuddy/features/snaps/snaps_routes.dart';

const Set<String> _publicPaths = {
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgot,
};

const Set<String> _entryPaths = {
  AppRoutes.splash,
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgot,
  AppRoutes.onboarding,
};

/// Auth redirect rules (pure function so it can be unit tested).
///
/// - not logged in -> `/login`
/// - logged in, onboarding not completed -> `/onboarding`
/// - otherwise -> into the app
@visibleForTesting
String? appRedirect({
  required String location,
  required AsyncValue<AuthUser?> auth,
  required AsyncValue<Profile?> profile,
}) {
  final atSplash = location == AppRoutes.splash;

  if (auth.isLoading && !auth.hasValue) {
    return atSplash ? null : AppRoutes.splash;
  }

  if (auth.valueOrNull == null) {
    return _publicPaths.contains(location) ? null : AppRoutes.login;
  }

  // Logged in: wait for the profile before deciding where to go.
  if (profile.isLoading || !profile.hasValue) {
    return atSplash ? null : AppRoutes.splash;
  }

  final completed = profile.valueOrNull?.onboardingCompleted ?? false;
  if (!completed) {
    return location == AppRoutes.onboarding ? null : AppRoutes.onboarding;
  }
  return _entryPaths.contains(location) ? AppRoutes.home : null;
}

/// Re-runs the redirect whenever auth or the profile changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentProfileProvider, (_, __) => notifyListeners());
  }
}

/// The app router. Merges every feature's route list.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      auth: ref.read(authStateProvider),
      profile: ref.read(currentProfileProvider),
    ),
    errorBuilder: (context, state) =>
        RouteErrorScreen(location: state.uri.toString()),
    routes: [
      ...authRoutes,
      ...onboardingRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          currentPath: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(routes: homeRoutes),
          StatefulShellBranch(routes: workoutsRoutes),
          StatefulShellBranch(routes: friendsRoutes),
          StatefulShellBranch(routes: profileRoutes),
        ],
      ),
      // Everything below is top-level (no bottom bar).
      ...dashboardRoutes,
      ...scheduleRoutes,
      ...motivationRoutes,
      ...challengesRoutes,
      ...nutritionRoutes,
      ...healthProfileRoutes,
      ...sleepRoutes,
      ...teamsRoutes,
      ...snapsRoutes,
      ...settingsRoutes,
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
