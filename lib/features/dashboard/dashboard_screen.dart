import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/dashboard/widgets/calorie_breakdown_card.dart';
import 'package:fitbuddy/features/dashboard/widgets/history_list.dart';
import 'package:fitbuddy/features/dashboard/widgets/rings_section.dart';
import 'package:fitbuddy/features/dashboard/widgets/week_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Progress rings, a 7-day bar chart, the calorie breakdown and history.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ChartMetric _metric = ChartMetric.steps;

  Future<void> _refresh() async {
    ref.invalidate(recentStatsProvider);
    await ref.read(recentStatsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentStatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: recent.when(
        loading: () => Center(
          child: Semantics(
            label: 'Loading your activity',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => _ErrorView(onRetry: _refresh),
        data: (days) => RefreshIndicator(
          onRefresh: _refresh,
          child: _buildContent(context, days),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<DailyStats> days) {
    final text = Theme.of(context).textTheme;
    final targets = ref.watch(dailyTargetsProvider);
    final breakdown = ref.watch(calorieBreakdownProvider).asData?.value;
    final week = days.sublist(days.length > 7 ? days.length - 7 : 0);
    final history = days.reversed.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        RingsSection(stats: days.last, targets: targets),
        const SizedBox(height: 24),
        Text('Last 7 days', style: text.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ChartMetric>(
          showSelectedIcon: false,
          segments: [
            for (final m in ChartMetric.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {_metric},
          onSelectionChanged: (s) => setState(() => _metric = s.first),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: WeekBarChart(
              days: week,
              metric: _metric,
              target: _metric.targetOf(targets),
            ),
          ),
        ),
        if (breakdown != null) ...[
          const SizedBox(height: 24),
          CalorieBreakdownCard(breakdown: breakdown),
        ],
        const SizedBox(height: 24),
        Text('History', style: text.titleMedium),
        const SizedBox(height: 4),
        HistoryList(days: history, targets: targets),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
              semanticLabel: 'Error',
            ),
            const SizedBox(height: 12),
            Text(
              "We couldn't load your activity.",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
