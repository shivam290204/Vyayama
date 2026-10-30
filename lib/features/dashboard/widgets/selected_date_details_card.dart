import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/widgets/concentric_rings_painter.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// Card showing the selected calendar date's detailed metrics with a large concentric ring display.
class SelectedDateDetailsCard extends StatelessWidget {
  const SelectedDateDetailsCard({
    super.key,
    required this.selectedDate,
    required this.stats,
    required this.targets,
    this.today,
  });

  final DateTime selectedDate;
  final DailyStats? stats;
  final DailyTargets targets;
  final DateTime? today;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final now = today ?? DateTime.now();
    final isToday = isSameDay(selectedDate, now);
    final isFuture = dayOnly(selectedDate).isAfter(dayOnly(now));

    final steps = stats?.steps ?? 0;
    final activeMinutes = stats?.activeMinutes ?? 0;
    final calories = stats?.calories ?? 0;

    final stepProgress = targets.steps > 0 ? (steps / targets.steps).clamp(0.0, 1.0) : 0.0;
    final activeProgress = targets.activeMinutes > 0
        ? (activeMinutes / targets.activeMinutes).clamp(0.0, 1.0)
        : 0.0;
    final calorieProgress = targets.activeCalories > 0
        ? (calories / targets.activeCalories).clamp(0.0, 1.0)
        : 0.0;

    final isTargetAchieved = targets.steps > 0 && steps >= targets.steps;
    final allAchieved = isTargetAchieved &&
        activeMinutes >= targets.activeMinutes &&
        calories >= targets.activeCalories;

    final monthName = _monthNames[selectedDate.month - 1];
    final weekdayName = _weekdays[selectedDate.weekday - 1];

    final cardBg = isDark
        ? AppPalette.darkSurfaceContainer
        : AppPalette.lightSurface;
    final textPrimary = isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted = isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header: 29 Oct > or Today, 29 October
            Row(
              children: [
                Text(
                  '${selectedDate.day} $monthName',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  weekdayName,
                  style: text.bodyMedium?.copyWith(
                    color: textMuted,
                  ),
                ),
                const Spacer(),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppPalette.limeGreen.withValues(alpha: 0.20)
                          : AppPalette.softLime,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                      ),
                    ),
                  )
                else if (isTargetAchieved)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppPalette.limeGreen.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppPalette.limeGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          allAchieved ? 'All targets met' : 'Target reached',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. Large concentric rings on left + detailed metrics on right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Large visual progress concentric rings
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(96, 96),
                        painter: ConcentricRingsPainter(
                          stepProgress: isFuture ? 0.0 : stepProgress,
                          activeMinutesProgress: isFuture ? 0.0 : activeProgress,
                          calorieProgress: isFuture ? 0.0 : calorieProgress,
                          stepColor: AppPalette.activitySteps,
                          activeMinutesColor: AppPalette.activityMinutes,
                          calorieColor: AppPalette.activityCalories,
                          ringWidth: 6.0,
                          ringSpacing: 3.2,
                          trackOpacity: isDark ? 0.20 : 0.14,
                        ),
                      ),
                      // Center Icon
                      Icon(
                        allAchieved
                            ? Icons.emoji_events_rounded
                            : Icons.favorite_rounded,
                        size: 26,
                        color: isTargetAchieved
                            ? AppPalette.limeGreen
                            : (isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),

                // Right: Detailed numeric metrics with targets
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Metric 1: Steps
                      _MetricRow(
                        icon: Icons.directions_walk_rounded,
                        iconColor: AppPalette.activitySteps,
                        valueText: formatInt(steps),
                        targetText: '/ ${formatInt(targets.steps)}',
                        unit: 'steps',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Metric 2: Active Time
                      _MetricRow(
                        icon: Icons.access_time_rounded,
                        iconColor: AppPalette.activityMinutes,
                        valueText: '$activeMinutes',
                        targetText: '/ ${targets.activeMinutes}',
                        unit: 'mins',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Metric 3: Calories
                      _MetricRow(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: AppPalette.activityCalories,
                        valueText: '$calories',
                        targetText: '/ ${targets.activeCalories}',
                        unit: 'kcal',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.iconColor,
    required this.valueText,
    required this.targetText,
    required this.unit,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String valueText;
  final String targetText;
  final String unit;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final textPrimary = isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted = isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Text(
          valueText,
          style: text.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: textPrimary,
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$targetText $unit',
          style: text.bodySmall?.copyWith(
            color: textMuted,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
