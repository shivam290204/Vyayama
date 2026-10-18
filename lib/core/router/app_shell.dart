import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_bottom_bar.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/providers.dart';

/// Tab shell: Home, Workouts, Friends and Profile are branches. The center
/// Camera button pushes a full-screen route and is not a tab.
class AppShell extends ConsumerStatefulWidget {
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
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Periodically sync friend requests & inbox in background while app is active
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        ref.invalidate(friendRequestsProvider);
        ref.invalidate(inboxProvider);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(inboxProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hideBar =
        AppShell._fullScreenPrefixes.any(widget.currentPath.startsWith);

    // Play notification sound when a new friend request arrives (ignores cold boot)
    ref.listen<AsyncValue<List<FriendRequest>>>(friendRequestsProvider,
        (previous, next) {
      if (previous != null && previous.hasValue && next.hasValue) {
        final prevCount = previous.value!.where((r) => r.incoming).length;
        final nextCount = next.value!.where((r) => r.incoming).length;
        if (nextCount > prevCount) {
          AppSoundService.instance.playNotificationSound();
        }
      }
    });

    // Play notification sound when a new direct snap arrives (ignores cold boot)
    ref.listen<AsyncValue<List<ReceivedSnap>>>(inboxProvider, (previous, next) {
      if (previous != null && previous.hasValue && next.hasValue) {
        final prevCount = previous.value!.where((s) => s.isUnviewed).length;
        final nextCount = next.value!.where((s) => s.isUnviewed).length;
        if (nextCount > prevCount) {
          AppSoundService.instance.playNotificationSound();
        }
      }
    });

    final requests = ref.watch(incomingRequestCountProvider);
    final unviewedSnaps = ref.watch(unviewedSnapsCountProvider);
    final totalBadges = requests + unviewedSnaps;

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: hideBar
          ? null
          : AppBottomBar(
              selectedBranch: widget.navigationShell.currentIndex,
              friendsBadgeCount: totalBadges,
              onBranchSelected: (index) => widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              ),
              onCameraPressed: () => context.push(AppRoutes.snapsCamera),
            ),
    );
  }
}
