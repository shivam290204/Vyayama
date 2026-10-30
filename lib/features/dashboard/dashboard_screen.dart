import 'package:fitbuddy/core/services/step_tracking_service.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/dashboard/widgets/calorie_breakdown_card.dart';
import 'package:fitbuddy/features/dashboard/widgets/history_list.dart';
import 'package:fitbuddy/features/dashboard/monthly_activity_screen.dart';
import 'package:fitbuddy/features/dashboard/widgets/rings_section.dart';
import 'package:fitbuddy/features/dashboard/widgets/week_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Progress rings, a 7-day bar chart, the calorie breakdown and history.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ChartMetric _metric = ChartMetric.steps;

  @override
  void initState() {
    super.initState();
    StepTrackingService.instance.start();
  }

  Future<void> _refresh() async {
    await StepTrackingService.instance.refresh();
    ref.invalidate(recentStatsProvider);
    final month = ref.read(selectedCalendarMonthProvider);
    ref.invalidate(monthlyActivityProvider(month));
    await ref.read(recentStatsProvider.future);
  }

  Future<void> _promptActivityRecognition() async {
    final status = await Permission.activityRecognition.status;
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.settings, size: 36, color: Theme.of(ctx).colorScheme.primary),
          title: const Text('Permission in Android Settings'),
          content: const Text(
            'Physical activity recognition permission was previously disabled.\n\n'
            'To enable live hardware step tracking, please tap "Open Settings", then tap "Permissions", and allow "Physical activity".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.directions_walk, size: 36, color: Theme.of(ctx).colorScheme.primary),
        title: const Text('Physical Activity Tracking'),
        content: const Text(
          'Vyayama uses on-device hardware sensors (Step Counter) to measure your daily steps, active time, and movement consistency.\n\n'
          '• Your step counts are processed strictly on-device.\n'
          '• Data is never sold or used for advertising.\n'
          '• If declined, you can still sync via Health Connect or log steps manually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await StepTrackingService.instance.requestPermission();
      await _refresh();
    }
  }

  Future<void> _showLogStepsDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Steps'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add steps to today\'s total. Useful for treadmill workouts or quick testing.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('+250'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await StepTrackingService.instance.addManualSteps(250);
                    await _refresh();
                  },
                ),
                ActionChip(
                  label: const Text('+500'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await StepTrackingService.instance.addManualSteps(500);
                    await _refresh();
                  },
                ),
                ActionChip(
                  label: const Text('+1,000'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await StepTrackingService.instance.addManualSteps(1000);
                    await _refresh();
                  },
                ),
                ActionChip(
                  label: const Text('+2,500'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await StepTrackingService.instance.addManualSteps(2500);
                    await _refresh();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Or enter custom steps',
                hintText: 'e.g. 750',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.orange),
                label: const Text('Reset Today to 0 Steps', style: TextStyle(color: Colors.orange)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await StepTrackingService.instance.resetTodaySteps();
                  final repo = ref.read(dailyStatsRepositoryProvider);
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final resetStats = DailyStats(
                    date: today,
                    steps: 0,
                    calories: 0,
                    activeMinutes: 0,
                  );
                  await repo.upsert(resetStats);
                  ref.invalidate(recentStatsProvider);
                  await ref.read(recentStatsProvider.future);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Today\'s steps reset to 0! Walk around to test live counting.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final val = int.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                await StepTrackingService.instance.addManualSteps(val);
                await _refresh();
              }
            },
            child: const Text('Add Steps'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveStepStatsProvider, (previous, next) {
      ref.invalidate(recentStatsProvider);
    });
    final recent = ref.watch(recentStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Monthly Activity',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MonthlyActivityScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Steps',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Log Steps',
            onPressed: () => _showLogStepsDialog(context),
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ValueListenableBuilder<bool>(
            valueListenable: StepTrackingService.instance.hasPermission,
            builder: (context, granted, _) {
              if (granted) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_walk, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live step sensor paused',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tracking via Health Connect or manual entry. Tap to enable live pedometer.',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _promptActivityRecognition,
                    child: const Text('Enable'),
                  ),
                ],
              ),
            );
          },
        ),
        RingsSection(stats: days.last, targets: targets),
        const SizedBox(height: 8),
        ValueListenableBuilder<String>(
          valueListenable: StepTrackingService.instance.pedestrianStatus,
          builder: (context, movement, _) {
            final isMoving = movement == 'Walking';
            final isSensorReady = StepTrackingService.instance.isSensorActive.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: isMoving ? Colors.greenAccent : (isSensorReady ? Colors.lightGreen : scheme.outline),
                ),
                const SizedBox(width: 6),
                Text(
                  isMoving
                      ? '🚶 Movement detected • Walking'
                      : (isSensorReady ? 'Live sensor active • Walk or run to count' : 'Sensor idle • Tap Sync to refresh'),
                  style: text.bodySmall?.copyWith(
                    color: isMoving ? Colors.greenAccent : scheme.onSurfaceVariant,
                    fontWeight: isMoving ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
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
