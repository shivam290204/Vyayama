import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/router/app_bottom_bar.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
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
  RealtimeChannel? _realtimeChannel;

  int _knownIncomingRequests = -1;
  int _knownUnviewedSnaps = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRealtime();

    // Fast 5-second polling while app is active in foreground
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(friendRequestsProvider);
        ref.invalidate(inboxProvider);
      }
    });
  }

  void _initRealtime() {
    if (!Env.isSupabaseConfigured) return;
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('public:notifications_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'friendships',
            callback: (_) {
              if (mounted) ref.invalidate(friendRequestsProvider);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'snap_recipients',
            callback: (_) {
              if (mounted) ref.invalidate(inboxProvider);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[AppShell] Realtime subscribe error: $e');
    }
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
    if (_realtimeChannel != null && Env.isSupabaseConfigured) {
      try {
        Supabase.instance.client.removeChannel(_realtimeChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hideBar =
        AppShell._fullScreenPrefixes.any(widget.currentPath.startsWith);

    // Reset known counts if user switches accounts
    ref.listen<String>(currentUserIdProvider, (previous, next) {
      if (previous != next) {
        _knownIncomingRequests = -1;
        _knownUnviewedSnaps = -1;
      }
    });

    // Play notification sound on receiver's device when a new incoming friend request arrives
    ref.listen<AsyncValue<List<FriendRequest>>>(friendRequestsProvider,
        (previous, next) {
      if (next.hasValue) {
        final currentIncoming =
            next.value!.where((r) => r.incoming).length;
        if (_knownIncomingRequests >= 0 &&
            currentIncoming > _knownIncomingRequests) {
          // New friend request arrived for this user!
          AppSoundService.instance.playNotificationSound();
        }
        _knownIncomingRequests = currentIncoming;
      }
    });

    // Play notification sound on receiver's device when a new incoming direct snap arrives
    ref.listen<AsyncValue<List<ReceivedSnap>>>(inboxProvider, (previous, next) {
      if (next.hasValue) {
        final currentUnviewed =
            next.value!.where((s) => s.isUnviewed).length;
        if (_knownUnviewedSnaps >= 0 && currentUnviewed > _knownUnviewedSnaps) {
          // New snap arrived for this user!
          AppSoundService.instance.playNotificationSound();
        }
        _knownUnviewedSnaps = currentUnviewed;
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
