import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats_repository.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/dashboard/widgets/calendar_day_cell.dart';
import 'package:fitbuddy/features/dashboard/widgets/monthly_activity_calendar.dart';
import 'package:fitbuddy/features/dashboard/widgets/selected_date_details_card.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDailyStatsRepository implements DailyStatsRepository {
  _FakeDailyStatsRepository(this.statsList);

  final List<DailyStats> statsList;

  @override
  Future<List<DailyStats>> fetchRange(DateTime from, DateTime to) async {
    return statsList;
  }

  @override
  Future<void> upsert(DailyStats stats) async {}
}

void main() {
  group('MonthlyActivityCalendar Widget Tests', () {
    final testDate = DateTime(2026, 10, 29);
    final testMonth = DateTime(2026, 10, 1);

    final mockStats = [
      DailyStats(date: DateTime(2026, 10, 1), steps: 8500, activeMinutes: 45, calories: 350),
      DailyStats(date: DateTime(2026, 10, 29), steps: 7100, activeMinutes: 73, calories: 298),
    ];

    Widget createTestWidget({DailyStatsRepository? repo}) {
      return ProviderScope(
        overrides: [
          todayProvider.overrideWithValue(testDate),
          clockProvider.overrideWithValue(() => testDate),
          dailyStatsRepositoryProvider.overrideWithValue(
            repo ?? _FakeDailyStatsRepository(mockStats),
          ),
          selectedCalendarMonthProvider.overrideWith((ref) => testMonth),
          selectedCalendarDateProvider.overrideWith((ref) => testDate),
          dailyTargetsProvider.overrideWithValue(
            const DailyTargets(steps: 6000, activeMinutes: 90, activeCalories: 500),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MonthlyActivityCalendar(),
            ),
          ),
        ),
      );
    }

    testWidgets('1. Renders month header, target achieved text, and weekday row', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Heading: October 2026
      expect(find.text('October 2026'), findsOneWidget);

      // Target achieved summary: 2 targets achieved (Oct 1: 8500 >= 6000, Oct 29: 7100 >= 6000)
      expect(find.textContaining('Target achieved'), findsOneWidget);
      expect(find.textContaining('2/29 days'), findsOneWidget);

      // Metric totals
      expect(find.textContaining('15,600 steps'), findsOneWidget);
      expect(find.textContaining('118 mins'), findsOneWidget);
      expect(find.textContaining('648 kcal'), findsOneWidget);

      // Weekdays: S, M, T, W, T, F, S
      expect(find.text('S'), findsNWidgets(2)); // Sun & Sat
      expect(find.text('M'), findsOneWidget);
      expect(find.text('T'), findsNWidgets(2)); // Tue & Thu
      expect(find.text('W'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);

      // Grid day cells
      expect(find.byType(CalendarDayCell), findsWidgets);

      // Selected date details card
      expect(find.byType(SelectedDateDetailsCard), findsOneWidget);
      expect(find.text('29 Oct'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('7,100'), findsOneWidget);
      expect(find.text('/ 6,000 steps'), findsOneWidget);
      expect(find.text('73'), findsOneWidget);
      expect(find.text('/ 90 mins'), findsOneWidget);
      expect(find.text('298'), findsOneWidget);
      expect(find.text('/ 500 kcal'), findsOneWidget);
    });

    testWidgets('2. Tapping a day cell updates selected date details', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on Day 1 (Oct 1)
      final day1Finder = find.widgetWithText(CalendarDayCell, '1');
      expect(day1Finder, findsOneWidget);
      await tester.tap(day1Finder);
      await tester.pumpAndSettle();

      // Now SelectedDateDetailsCard shows 1 Oct
      expect(find.text('1 Oct'), findsOneWidget);
      expect(find.text('8,500'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(find.text('Target reached'), findsOneWidget);
    });

    testWidgets('3. Month navigation buttons change month', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);

      // Tap Previous Month chevron
      final prevBtn = find.byTooltip('Previous month');
      expect(prevBtn, findsOneWidget);
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);

      // Tap Next Month chevron twice
      final nextBtn = find.byTooltip('Next month');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsOneWidget);

      await tester.tap(nextBtn);
      await tester.pumpAndSettle();
      expect(find.text('November 2026'), findsOneWidget);
    });
  });
}

