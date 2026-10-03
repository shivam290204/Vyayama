import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:flutter/material.dart';

/// Last 7 days of a pair; filled circles are days both friends sent.
class StreakHistoryStrip extends StatelessWidget {
  const StreakHistoryStrip({super.key, required this.streak, required this.nowUtc});

  final SnapStreak streak;
  final DateTime nowUtc;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = SnapStreakCalculator.localDate(nowUtc, streak.timezone);
    final done = SnapStreakCalculator.completedDays(streak, nowUtc).toSet();
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final doneCount = days.where(done.contains).length;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Streak history: $doneCount of the last 7 days completed',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in days)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done.contains(d)
                        ? scheme.tertiary
                        : scheme.surfaceContainerHighest,
                  ),
                  child: done.contains(d)
                      ? Icon(Icons.check, size: 18, color: scheme.onTertiary)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(_letters[d.weekday - 1], style: text.labelSmall),
              ],
            ),
        ],
      ),
    );
  }
}
