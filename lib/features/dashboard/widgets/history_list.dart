import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// Recent days with their numbers, newest first. A check mark shows when
/// the step target was reached.
class HistoryList extends StatelessWidget {
  /// Creates the list.
  const HistoryList({super.key, required this.days, required this.targets});

  /// Days, newest first.
  final List<DailyStats> days;

  /// Daily goals, used for the check mark.
  final DailyTargets targets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (days.every((d) => d.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No activity recorded yet. Your days will show up here.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      children: [
        for (final d in days)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(formatLongDate(d.date)),
            subtitle: Text(
              d.isEmpty
                  ? 'No activity recorded'
                  : '${formatInt(d.steps)} steps · ${formatInt(d.calories)} kcal '
                      '· ${d.activeMinutes} min',
            ),
            trailing: d.steps >= targets.steps
                ? Icon(
                    Icons.check_circle,
                    color: scheme.primary,
                    semanticLabel: 'Step target reached',
                  )
                : null,
          ),
      ],
    );
  }
}
