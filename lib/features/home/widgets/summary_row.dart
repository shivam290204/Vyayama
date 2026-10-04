import 'dart:async';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/widgets/bouncing_card.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/home/widgets/progress_ring.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Animated circular progress rings for today's steps, calories, and active
/// minutes. Tapping opens the Dashboard.
///
/// Live-updates every 60 seconds while visible and the app is in the
/// foreground. Cancels the timer on dispose and when backgrounded.
class SummaryRow extends ConsumerStatefulWidget {
  /// Creates the row.
  const SummaryRow({super.key});

  @override
  ConsumerState<SummaryRow> createState() => _SummaryRowState();
}

class _SummaryRowState extends ConsumerState<SummaryRow>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh immediately on app resume.
      ref.invalidate(recentStatsProvider);
      _startTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopTimer();
    }
  }

  void _startTimer() {
    _stopTimer();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(recentStatsProvider);
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(todayStatsProvider);
    final targets = ref.watch(dailyTargetsProvider);

    return BouncingCard(
      margin: EdgeInsets.zero,
      onTap: () => context.push(AppRoutes.dashboard),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: stats.when(
            loading: () => _LoadingSkeleton(),
            error: (_, __) => _ErrorState(
              onRetry: () => ref.invalidate(recentStatsProvider),
            ),
            data: (s) => _RingsRow(stats: s, targets: targets),
          ),
        ),
      ),
    );
  }
}

class _RingsRow extends StatelessWidget {
  const _RingsRow({required this.stats, required this.targets});

  final DailyStats stats;
  final DailyTargets targets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trackColor = scheme.surfaceContainerHighest;

    // Lighter tint of primary for active minutes.
    final primaryTint = Color.lerp(scheme.primary, scheme.surface, 0.35)!;

    return Semantics(
      button: true,
      label: "Today's activity. Open dashboard",
      value: '${formatInt(stats.steps)} steps, '
          '${formatInt(stats.calories)} kilocalories, '
          '${stats.activeMinutes} active minutes',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: ProgressRing(
              value: stats.steps,
              goal: targets.steps,
              ringColor: scheme.primary,
              trackColor: trackColor,
              icon: Icons.directions_walk,
              label: 'steps',
              semanticGoalLabel: 'Steps',
            ),
          ),
          Flexible(
            child: ProgressRing(
              value: stats.calories,
              goal: targets.activeCalories,
              ringColor: scheme.secondary,
              trackColor: trackColor,
              icon: Icons.local_fire_department,
              label: 'kcal',
              semanticGoalLabel: 'Calories',
            ),
          ),
          Flexible(
            child: ProgressRing(
              value: stats.activeMinutes,
              goal: targets.activeMinutes,
              ringColor: primaryTint,
              trackColor: trackColor,
              icon: Icons.timer_outlined,
              label: 'min active',
              semanticGoalLabel: 'Active minutes',
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(child: ProgressRingSkeleton()),
        Flexible(child: ProgressRingSkeleton()),
        Flexible(child: ProgressRingSkeleton()),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        const Icon(Icons.error_outline, semanticLabel: 'Error'),
        const SizedBox(width: 12),
        const Expanded(child: Text("Couldn't load your activity")),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
