import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/dashboard/logic/monthly_activity_logic.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// Month header with previous/next navigation and monthly aggregated targets.
class MonthlySummaryHeader extends StatelessWidget {
  const MonthlySummaryHeader({
    super.key,
    required this.summary,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final MonthlyActivitySummary summary;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final month = summary.month;
    final monthName = _monthNames[month.month - 1];
    final yearStr = '${month.year}';

    final textMuted = isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;
    final textPrimary = isDark ? AppPalette.darkText : AppPalette.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Month Navigation Header: < October 2026 >
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 28),
              tooltip: 'Previous month',
              onPressed: onPreviousMonth,
            ),
            Text(
              '$monthName $yearStr',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 28),
              tooltip: 'Next month',
              onPressed: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Target Achieved Summary: Target achieved 18/29 days
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text.rich(
            TextSpan(
              style: text.bodyMedium?.copyWith(color: textMuted),
              children: [
                const TextSpan(text: 'Target achieved '),
                TextSpan(
                  text:
                      '${summary.targetDaysAchieved}/${summary.totalDaysEvaluated} days',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // 3. Metric Totals: 204,832 steps • 2,084 mins • 8,884 kcal
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                '${formatInt(summary.totalSteps)} steps',
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppPalette.limeGreen,
                ),
              ),
              Text(
                '  •  ',
                style: TextStyle(color: textMuted.withValues(alpha: 0.5)),
              ),
              Text(
                '${formatInt(summary.totalActiveMinutes)} mins',
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppPalette.activityMinutes,
                ),
              ),
              if (summary.totalCalories > 0) ...[
                Text(
                  '  •  ',
                  style: TextStyle(color: textMuted.withValues(alpha: 0.5)),
                ),
                Text(
                  '${formatInt(summary.totalCalories)} kcal',
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppPalette.activityCalories,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
