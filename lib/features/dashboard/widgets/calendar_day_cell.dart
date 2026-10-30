import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/dashboard/logic/monthly_activity_logic.dart';
import 'package:fitbuddy/features/dashboard/widgets/concentric_rings_painter.dart';
import 'package:flutter/material.dart';

/// One day cell in the monthly activity calendar grid with concentric rings.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.dayModel,
    required this.isSelected,
    required this.onTap,
    this.size = 46.0,
  });

  final CalendarDayModel dayModel;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final date = dayModel.date;
    final isCurrentMonth = dayModel.isCurrentMonth;
    final isToday = dayModel.isToday;
    final isFuture = dayModel.isFuture;

    // Distinct activity ring colors following Vyayama & Samsung Health reference
    final stepColor = AppPalette.activitySteps;
    final activeColor = AppPalette.activityMinutes;
    final calorieColor = AppPalette.activityCalories;

    // Date text styling
    Color dateColor;
    if (!isCurrentMonth) {
      dateColor = (isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted)
          .withValues(alpha: 0.35);
    } else if (isFuture) {
      dateColor = (isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted)
          .withValues(alpha: 0.60);
    } else if (isSelected) {
      dateColor = isDark ? Colors.white : AppPalette.forestGreen;
    } else {
      dateColor = isDark ? AppPalette.darkText : AppPalette.lightText;
    }

    final fontWeight = isToday || isSelected ? FontWeight.w700 : FontWeight.w500;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${date.day} ${date.month}, '
          '${dayModel.steps} steps, '
          '${dayModel.activeMinutes} active minutes, '
          '${dayModel.isTargetAchieved ? 'target achieved' : 'in progress'}, '
          '${isToday ? 'today, ' : ''}'
          '${isSelected ? 'selected' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: AppPalette.limeGreen.withValues(alpha: 0.15),
        highlightColor: Colors.transparent,
        child: Container(
          width: size,
          height: size + 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? (isDark
                    ? AppPalette.limeGreen.withValues(alpha: 0.16)
                    : AppPalette.softLime.withValues(alpha: 0.50))
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? AppPalette.limeGreen
                  : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Concentric 3-ring progress indicators
              CustomPaint(
                size: Size(size - 4, size - 4),
                painter: ConcentricRingsPainter(
                  stepProgress: isCurrentMonth ? dayModel.stepProgress : 0.0,
                  activeMinutesProgress:
                      isCurrentMonth ? dayModel.activeMinutesProgress : 0.0,
                  calorieProgress:
                      isCurrentMonth ? dayModel.calorieProgress : 0.0,
                  stepColor: stepColor,
                  activeMinutesColor: activeColor,
                  calorieColor: calorieColor,
                  trackOpacity: isCurrentMonth ? 0.18 : 0.06,
                  ringWidth: 2.4,
                  ringSpacing: 1.4,
                ),
              ),
              // Day number
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      color: dateColor,
                      fontSize: 13,
                      fontWeight: fontWeight,
                      height: 1.0,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppPalette.limeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
