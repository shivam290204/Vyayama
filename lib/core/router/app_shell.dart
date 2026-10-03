import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_bottom_bar.dart';
import 'package:fitbuddy/core/router/app_routes.dart';

/// Tab shell: Home, Workouts, Friends and Profile are branches. The center
/// Camera button pushes a full-screen route and is not a tab.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.currentPath,
  });

  final StatefulNavigationShell navigationShell;
  final String currentPath;

  /// Paths inside a tab branch that must hide the bottom bar.
  static const List<String> _fullScreenPrefixes = [
    AppRoutes.workoutSessionPrefix,
  ];

  @override
  Widget build(BuildContext context) {
    final hideBar = _fullScreenPrefixes.any(currentPath.startsWith);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideBar
          ? null
          : AppBottomBar(
              selectedBranch: navigationShell.currentIndex,
              onBranchSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              onCameraPressed: () => context.push(AppRoutes.snapsCamera),
            ),
    );
  }
}
