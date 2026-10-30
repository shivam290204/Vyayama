import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/dashboard/logic/monthly_activity_logic.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/dashboard/widgets/calendar_day_cell.dart';
import 'package:fitbuddy/features/dashboard/widgets/monthly_summary_header.dart';
import 'package:fitbuddy/features/dashboard/widgets/selected_date_details_card.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full monthly activity calendar widget with concentric progress rings,
/// month navigation, monthly aggregation totals, and selected date details.
class MonthlyActivityCalendar extends ConsumerWidget {
  const MonthlyActivityCalendar({super.key});

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentMonth = ref.watch(selectedCalendarMonthProvider);
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final targets = ref.watch(dailyTargetsProvider);
    final today = ref.watch(todayProvider);

    final monthlyAsync = ref.watch(monthlyActivityProvider(currentMonth));

    final cardBg = isDark
        ? AppPalette.darkSurfaceContainer
        : AppPalette.lightSurface;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: monthlyAsync.when(
          loading: () => const SizedBox(
            height: 380,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => SizedBox(
            height: 240,
            child: Center(
              child: Text(
                'Could not load monthly activity: $err',
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (summary) {
            // Generate full 7-column calendar grid
            final grid = MonthlyActivityLogic.generateGrid(
              month: currentMonth,
              dailyMap: summary.dailyMap,
              targets: targets,
              today: today,
            );

            final selectedDayStats = summary.statsForDate(selectedDate);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Monthly Summary & Navigation Header
                MonthlySummaryHeader(
                  summary: summary,
                  onPreviousMonth: () {
                    final prev = MonthlyActivityLogic.previousMonth(currentMonth);
                    ref.read(selectedCalendarMonthProvider.notifier).state = prev;
                  },
                  onNextMonth: () {
                    final next = MonthlyActivityLogic.nextMonth(currentMonth);
                    ref.read(selectedCalendarMonthProvider.notifier).state = next;
                  },
                ),
                const SizedBox(height: 18),

                // 2. Weekday Header Row (S M T W T F S)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final isSunday = index == 0;
                      return SizedBox(
                        width: 44,
                        child: Center(
                          child: Text(
                            _weekdays[index],
                            style: TextStyle(
                              color: isSunday
                                  ? (isDark ? AppPalette.softCoral : AppPalette.deepCoral)
                                  : (isDark
                                      ? AppPalette.darkTextMuted
                                      : AppPalette.lightTextMuted),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),

                // 3. 7-Column Calendar Grid with Concentric Activity Rings
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: GridView.builder(
                    key: ValueKey('${currentMonth.year}-${currentMonth.month}'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: grid.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.88,
                    ),
                    itemBuilder: (context, index) {
                      final dayModel = grid[index];
                      final isSelected = dayModel.date.year == selectedDate.year &&
                          dayModel.date.month == selectedDate.month &&
                          dayModel.date.day == selectedDate.day;

                      return CalendarDayCell(
                        dayModel: dayModel,
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(selectedCalendarDateProvider.notifier).state =
                              dayModel.date;

                          // If tapped day belongs to adjacent month, switch month view too
                          if (!dayModel.isCurrentMonth) {
                            ref
                                .read(selectedCalendarMonthProvider.notifier)
                                .state = DateTime(
                              dayModel.date.year,
                              dayModel.date.month,
                              1,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Selected Date Details Card with Large Concentric Rings
                SelectedDateDetailsCard(
                  selectedDate: selectedDate,
                  stats: selectedDayStats,
                  targets: targets,
                  today: today,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
