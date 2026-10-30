import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/logic/monthly_activity_logic.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyActivityLogic Unit Tests', () {
    const defaultTargets = DailyTargets(
      steps: 8000,
      activeMinutes: 30,
      activeCalories: 400,
    );

    test('1. Leap year and month end dates calculation', () {
      // February in leap year (2024) -> 29 days
      final feb2024End = MonthlyActivityLogic.endOfMonth(DateTime(2024, 2));
      expect(feb2024End.day, equals(29));
      expect(feb2024End.month, equals(2));

      // February in non-leap year (2025) -> 28 days
      final feb2025End = MonthlyActivityLogic.endOfMonth(DateTime(2025, 2));
      expect(feb2025End.day, equals(28));
      expect(feb2025End.month, equals(2));

      // 30-day month (April, June, September, November)
      expect(MonthlyActivityLogic.endOfMonth(DateTime(2026, 4)).day, equals(30));
      expect(MonthlyActivityLogic.endOfMonth(DateTime(2026, 9)).day, equals(30));

      // 31-day month (October)
      expect(MonthlyActivityLogic.endOfMonth(DateTime(2026, 10)).day, equals(31));
    });

    test('2. Month navigation across year boundaries', () {
      final oct2026 = DateTime(2026, 10, 15);
      expect(MonthlyActivityLogic.nextMonth(oct2026), equals(DateTime(2026, 11, 1)));
      expect(MonthlyActivityLogic.previousMonth(oct2026), equals(DateTime(2026, 9, 1)));

      // December -> January next year
      final dec2026 = DateTime(2026, 12, 1);
      expect(MonthlyActivityLogic.nextMonth(dec2026), equals(DateTime(2027, 1, 1)));

      // January -> December previous year
      final jan2026 = DateTime(2026, 1, 1);
      expect(MonthlyActivityLogic.previousMonth(jan2026), equals(DateTime(2025, 12, 1)));
    });

    test('3. Calendar grid weekday alignment (Sunday first)', () {
      // October 2026 starts on Thursday (weekday 4 in Dart: Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6, Sun=7)
      // When Sunday is first column (index 0), leading days should be:
      // Sun (Sep 27), Mon (Sep 28), Tue (Sep 29), Wed (Sep 30) -> 4 leading days
      final grid = MonthlyActivityLogic.generateGrid(
        month: DateTime(2026, 10, 1),
        dailyMap: {},
        targets: defaultTargets,
        today: DateTime(2026, 10, 29),
        firstDayOfWeek: DateTime.sunday,
      );

      // Total cells must be a multiple of 7
      expect(grid.length % 7, equals(0));
      expect(grid.length, equals(35)); // 4 leading + 31 current = 35 (exact 5 weeks)

      // First cell is Sep 27, 2026 (previous month)
      expect(grid.first.date.year, equals(2026));
      expect(grid.first.date.month, equals(9));
      expect(grid.first.date.day, equals(27));
      expect(grid.first.isCurrentMonth, isFalse);

      // Fifth cell is Oct 1, 2026 (first day of current month)
      expect(grid[4].date.day, equals(1));
      expect(grid[4].isCurrentMonth, isTrue);

      // Last cell is Oct 31, 2026 (which is a Saturday, so 0 trailing days needed for 35)
      expect(grid.last.date.day, equals(31));
      expect(grid.last.isCurrentMonth, isTrue);
    });

    test('4. Monthly aggregation totals and target achieved count', () {
      final month = DateTime(2026, 10, 1);
      final today = DateTime(2026, 10, 29);

      final rows = [
        DailyStats(date: DateTime(2026, 10, 1), steps: 8500, activeMinutes: 40, calories: 340), // Target achieved
        DailyStats(date: DateTime(2026, 10, 2), steps: 10200, activeMinutes: 55, calories: 420), // Target achieved
        DailyStats(date: DateTime(2026, 10, 3), steps: 4000, activeMinutes: 20, calories: 160), // Not achieved
        DailyStats(date: DateTime(2026, 10, 29), steps: 7100, activeMinutes: 73, calories: 298), // Not achieved
        // Adjacent month row (should be ignored for October totals)
        DailyStats(date: DateTime(2026, 9, 30), steps: 9000, activeMinutes: 30, calories: 350),
      ];

      final summary = MonthlyActivityLogic.computeSummary(
        rows: rows,
        month: month,
        targets: defaultTargets,
        today: today,
      );

      expect(summary.totalSteps, equals(8500 + 10200 + 4000 + 7100)); // 29,800
      expect(summary.totalActiveMinutes, equals(40 + 55 + 20 + 73)); // 188
      expect(summary.totalCalories, equals(340 + 420 + 160 + 298)); // 1,218
      expect(summary.targetDaysAchieved, equals(2)); // Oct 1 & Oct 2
      expect(summary.totalDaysEvaluated, equals(29)); // Current day in October
      expect(summary.totalDaysInMonth, equals(31));
    });

    test('5. Missing and zero activity handling', () {
      final month = DateTime(2026, 10, 1);
      final today = DateTime(2026, 10, 10);

      // Single entry with zero steps
      final rows = [
        DailyStats(date: DateTime(2026, 10, 5), steps: 0, activeMinutes: 0, calories: 0),
      ];

      final summary = MonthlyActivityLogic.computeSummary(
        rows: rows,
        month: month,
        targets: defaultTargets,
        today: today,
      );

      expect(summary.totalSteps, equals(0));
      expect(summary.targetDaysAchieved, equals(0));
      expect(summary.totalDaysEvaluated, equals(10));

      final grid = MonthlyActivityLogic.generateGrid(
        month: month,
        dailyMap: summary.dailyMap,
        targets: defaultTargets,
        today: today,
      );

      final oct5 = grid.firstWhere((c) => c.isCurrentMonth && c.date.day == 5);
      expect(oct5.hasActivity, isFalse);
      expect(oct5.stepProgress, equals(0.0));
      expect(oct5.isTargetAchieved, isFalse);

      final oct6 = grid.firstWhere((c) => c.isCurrentMonth && c.date.day == 6);
      expect(oct6.stats, isNull);
      expect(oct6.hasActivity, isFalse);
      expect(oct6.stepProgress, equals(0.0));
    });

    test('6. Future dates are never counted as target achieved or evaluated', () {
      final month = DateTime(2026, 10, 1);
      final today = DateTime(2026, 10, 15);

      final rows = [
        DailyStats(date: DateTime(2026, 10, 10), steps: 9000, activeMinutes: 45, calories: 360),
      ];

      final grid = MonthlyActivityLogic.generateGrid(
        month: month,
        dailyMap: {for (final r in rows) dayKey(r.date): r},
        targets: defaultTargets,
        today: today,
      );

      final oct20 = grid.firstWhere((c) => c.isCurrentMonth && c.date.day == 20);
      expect(oct20.isFuture, isTrue);
      expect(oct20.isToday, isFalse);
      expect(oct20.stepProgress, equals(0.0));
      expect(oct20.isTargetAchieved, isFalse);

      final oct15 = grid.firstWhere((c) => c.isCurrentMonth && c.date.day == 15);
      expect(oct15.isToday, isTrue);
      expect(oct15.isFuture, isFalse);
    });

    test('7. Targets exceeded visually caps at 1.0 while retaining true value', () {
      final month = DateTime(2026, 10, 1);
      final today = DateTime(2026, 10, 20);

      final row = DailyStats(
        date: DateTime(2026, 10, 5),
        steps: 16000, // 200% of target
        activeMinutes: 90, // 300% of target
        calories: 800, // 200% of target
      );

      final grid = MonthlyActivityLogic.generateGrid(
        month: month,
        dailyMap: {dayKey(row.date): row},
        targets: defaultTargets,
        today: today,
      );

      final cell = grid.firstWhere((c) => c.isCurrentMonth && c.date.day == 5);
      expect(cell.isTargetAchieved, isTrue);
      expect(cell.stepProgress, equals(1.0)); // Visual clamp at 100%
      expect(cell.activeMinutesProgress, equals(1.0));
      expect(cell.calorieProgress, equals(1.0));
      expect(cell.steps, equals(16000)); // True steps intact
      expect(cell.activeMinutes, equals(90));
      expect(cell.calories, equals(800));
    });
  });
}

