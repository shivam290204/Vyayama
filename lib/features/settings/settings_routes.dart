import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/settings/screens/settings_screen.dart';

/// Settings is a top-level route (pushed over the tab shell).
final List<RouteBase> settingsRoutes = [
  GoRoute(
    path: AppRoutes.settings,
    builder: (context, state) => const SettingsScreen(),
  ),
];
