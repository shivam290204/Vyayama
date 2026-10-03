import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/widgets/stat_ring.dart';
import 'package:flutter/material.dart';

/// Three progress rings: steps, calories and active time.
class RingsSection extends StatelessWidget {
  /// Creates the section.
  const RingsSection({super.key, required this.stats, required this.targets});

  /// Today's numbers.
  final DailyStats stats;

  /// Daily goals.
  final DailyTargets targets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ring =
                (constraints.maxWidth / 3 - 16).clamp(72.0, 120.0).toDouble();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: StatRing(
                      label: 'Steps',
                      icon: Icons.directions_walk,
                      value: stats.steps,
                      target: targets.steps,
                      unit: 'steps',
                      color: scheme.primary,
                      size: ring,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: StatRing(
                      label: 'Calories',
                      icon: Icons.local_fire_department,
                      value: stats.calories,
                      target: targets.activeCalories,
                      unit: 'kcal',
                      color: scheme.tertiary,
                      size: ring,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: StatRing(
                      label: 'Active time',
                      icon: Icons.timer_outlined,
                      value: stats.activeMinutes,
                      target: targets.activeMinutes,
                      unit: 'min',
                      color: scheme.secondary,
                      size: ring,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
