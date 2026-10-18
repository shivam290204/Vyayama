import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_bottom_bar.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/snaps/providers.dart';

/// Tab shell: Home, Workouts, Friends and Profile are branches. The center
/// Camera button pushes a full-screen route and is not a tab.
class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final hideBar = _fullScreenPrefixes.any(currentPath.startsWith);

    // Play notification sound when a new friend request arrives
    ref.listen<int>(incomingRequestCountProvider, (previous, next) {
      if (previous != null && next > previous) {
        AppSoundService.instance.playNotificationSound();
      }
    });

    // Play notification sound when a new snap arrives
    ref.listen<int>(unviewedSnapsCountProvider, (previous, next) {
      if (previous != null && next > previous) {
        AppSoundService.instance.playNotificationSound();
      }
    });

    final requests = ref.watch(incomingRequestCountProvider);
    final unviewedSnaps = ref.watch(unviewedSnapsCountProvider);
    final totalBadges = requests + unviewedSnaps;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: hideBar
          ? null
          : AppBottomBar(
              selectedBranch: navigationShell.currentIndex,
              friendsBadgeCount: totalBadges,
              onBranchSelected: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              onCameraPressed: () => context.push(AppRoutes.snapsCamera),
            ),
    );
  }
}
