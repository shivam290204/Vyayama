import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/dashboard_screen.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats_repository.dart';
import 'package:fitbuddy/features/dashboard/monthly_activity_screen.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/dashboard/widgets/monthly_activity_calendar.dart';
import 'package:fitbuddy/features/dashboard/widgets/week_bar_chart.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockDailyStatsRepository implements DailyStatsRepository {
  _MockDailyStatsRepository(this.stats);

  final List<DailyStats> stats;

  @override
  Future<List<DailyStats>> fetchRange(DateTime from, DateTime to) async => stats;

  @override
  Future<void> upsert(DailyStats stats) async {}
}

void main() {
  group('Dashboard Calendar Navigation Tests', () {
    final testDate = DateTime(2026, 10, 29);
    final mockDays = [
      DailyStats(date: DateTime(2026, 10, 28), steps: 5000, activeMinutes: 30, calories: 250),
      DailyStats(date: DateTime(2026, 10, 29), steps: 7100, activeMinutes: 73, calories: 298),
    ];

    Widget createTestApp() {
      return ProviderScope(
        overrides: [
          todayProvider.overrideWithValue(testDate),
          clockProvider.overrideWithValue(() => testDate),
          dailyStatsRepositoryProvider.overrideWithValue(_MockDailyStatsRepository(mockDays)),
          recentStatsProvider.overrideWith((ref) => Future.value(mockDays)),
          dailyTargetsProvider.overrideWithValue(
            const DailyTargets(steps: 6000, activeMinutes: 90, activeCalories: 500),
          ),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets('Dashboard has clean layout without duplicate segment and navigates to MonthlyActivityScreen via calendar icon', (tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // 1. Verifies Dashboard title
      expect(find.text('Dashboard'), findsOneWidget);

      // 2. Verifies SegmentedButton for Today/Monthly Activity is removed; only ChartMetric selector exists
      expect(find.byType(SegmentedButton<ChartMetric>), findsOneWidget);
      expect(find.text('Monthly Activity'), findsNothing); // No tab or button on Dashboard
      expect(find.text('Open Monthly Activity Calendar'), findsNothing); // Removed from bottom

      // 3. Calendar icon exists in AppBar
      final calendarIconFinder = find.byTooltip('Monthly Activity');
      expect(calendarIconFinder, findsOneWidget);

      // 4. Tap the calendar icon -> navigates to MonthlyActivityScreen
      await tester.tap(calendarIconFinder);
      await tester.pumpAndSettle();

      // 5. Now on MonthlyActivityScreen
      expect(find.byType(MonthlyActivityScreen), findsOneWidget);
      expect(find.text('Daily Activity'), findsOneWidget);
      expect(find.byType(MonthlyActivityCalendar), findsOneWidget);

      // 6. Back button exists and returns to Dashboard
      final backButtonFinder = find.byType(BackButton);
      expect(backButtonFinder, findsOneWidget);

      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      // 7. Returned back to Dashboard
      expect(find.byType(MonthlyActivityScreen), findsNothing);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
