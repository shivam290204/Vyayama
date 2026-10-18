import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/router/app_bottom_bar.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/features/friends/providers.dart';
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
  static const _kLastIncomingCountKey = 'last_seen_incoming_requests_count';
  static const _kLastUnviewedSnapsKey = 'last_seen_unviewed_snaps_count';

  Timer? _pollingTimer;
  RealtimeChannel? _realtimeChannel;
  int _lastIncomingCount = 0;
  int _lastUnviewedSnapsCount = 0;
  bool _initializedPrefs = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLastSeenCounts();
    _initRealtime();

    // Fast 5-second polling while app is active in foreground
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(friendRequestsProvider);
        ref.invalidate(inboxProvider);
      }
    });
  }

  Future<void> _initLastSeenCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastIncomingCount = prefs.getInt(_kLastIncomingCountKey) ?? 0;
      _lastUnviewedSnapsCount = prefs.getInt(_kLastUnviewedSnapsKey) ?? 0;
      _initializedPrefs = true;

      if (mounted) {
        // Check if new items arrived while the app was closed
        final currentReqs = ref.read(incomingRequestCountProvider);
        if (currentReqs > _lastIncomingCount) {
          AppSoundService.instance.playNotificationSound();
        }
        _lastIncomingCount = currentReqs;
        await prefs.setInt(_kLastIncomingCountKey, currentReqs);

        final currentSnaps = ref.read(unviewedSnapsCountProvider);
        if (currentSnaps > _lastUnviewedSnapsCount) {
          AppSoundService.instance.playNotificationSound();
        }
        _lastUnviewedSnapsCount = currentSnaps;
        await prefs.setInt(_kLastUnviewedSnapsKey, currentSnaps);
      }
    } catch (_) {
      _initializedPrefs = true;
    }
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

  void _onIncomingRequestsUpdated(int currentCount) {
    if (!_initializedPrefs) return;
    if (currentCount > _lastIncomingCount) {
      // Incoming request arrived for receiver!
      AppSoundService.instance.playNotificationSound();
    }
    _lastIncomingCount = currentCount;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_kLastIncomingCountKey, currentCount);
    }).catchError((_) {});
  }

  void _onUnviewedSnapsUpdated(int currentCount) {
    if (!_initializedPrefs) return;
    if (currentCount > _lastUnviewedSnapsCount) {
      // Incoming snap arrived for receiver!
      AppSoundService.instance.playNotificationSound();
    }
    _lastUnviewedSnapsCount = currentCount;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt(_kLastUnviewedSnapsKey, currentCount);
    }).catchError((_) {});
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

    // Play notification sound on receiver's device when a new incoming friend request arrives
    ref.listen<int>(incomingRequestCountProvider, (previous, next) {
      _onIncomingRequestsUpdated(next);
    });

    // Play notification sound on receiver's device when a new incoming direct snap arrives
    ref.listen<int>(unviewedSnapsCountProvider, (previous, next) {
      _onUnviewedSnapsUpdated(next);
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
