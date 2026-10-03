import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compact row with today's steps, calories and active minutes.
/// Tapping opens the Dashboard.
class SummaryRow extends ConsumerWidget {
  /// Creates the row.
  const SummaryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(todayStatsProvider);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.dashboard),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: stats.when(
              loading: () => const Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
              error: (_, __) => Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.error_outline, semanticLabel: 'Error'),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Couldn't load your activity")),
                  TextButton(
                    onPressed: () => ref.invalidate(recentStatsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
              data: (s) => _Stats(stats: s),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final DailyStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: "Today's activity. Open dashboard",
      value: '${formatInt(stats.steps)} steps, '
          '${formatInt(stats.calories)} kilocalories, '
          '${stats.activeMinutes} active minutes',
      excludeSemantics: true,
      child: Row(
        children: [
          _Stat(
            icon: Icons.directions_walk,
            color: scheme.primary,
            value: formatInt(stats.steps),
            label: 'steps',
          ),
          _Stat(
            icon: Icons.local_fire_department,
            color: scheme.tertiary,
            value: formatInt(stats.calories),
            label: 'kcal',
          ),
          _Stat(
            icon: Icons.timer_outlined,
            color: scheme.secondary,
            value: '${stats.activeMinutes}',
            label: 'min active',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: text.titleMedium),
          ),
          Text(label, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
