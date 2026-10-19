import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocalDailyStatsStorage Offline Tests', () {
    test('saves and retrieves daily stats offline', () async {
      final storage = LocalDailyStatsStorage.instance;
      final today = DateTime.now();

      final stats = DailyStats(
        date: today,
        steps: 4250,
        calories: 170,
        activeMinutes: 43,
      );

      await storage.save(stats);

      final loaded = await storage.get(today);
      expect(loaded, isNotNull);
      expect(loaded!.steps, equals(4250));
      expect(loaded.calories, equals(170));
      expect(loaded.activeMinutes, equals(43));
    });

    test('retrieves range of daily stats across multiple days offline', () async {
      final storage = LocalDailyStatsStorage.instance;
      final now = DateTime.now();
      final day1 = DateTime(now.year, now.month, now.day - 2);
      final day2 = DateTime(now.year, now.month, now.day - 1);
      final day3 = DateTime(now.year, now.month, now.day);

      await storage.save(DailyStats(
        date: day1,
        steps: 3000,
        calories: 120,
        activeMinutes: 30,
      ));
      await storage.save(DailyStats(
        date: day2,
        steps: 6500,
        calories: 260,
        activeMinutes: 65,
      ));
      await storage.save(DailyStats(
        date: day3,
        steps: 8000,
        calories: 320,
        activeMinutes: 80,
      ));

      final range = await storage.getRange(day1, day3);
      expect(range.length, equals(3));
      expect(range[0].steps, equals(3000));
      expect(range[1].steps, equals(6500));
      expect(range[2].steps, equals(8000));
    });

    test('tracks pending sync dates and clears them after sync', () async {
      final storage = LocalDailyStatsStorage.instance;
      final date = DateTime(2026, 10, 19);
      final k = dayKey(date);

      await storage.save(DailyStats(date: date, steps: 5000), markPendingSync: true);

      final pending = await storage.getPendingSyncDates();
      expect(pending, contains(k));

      await storage.clearPendingSyncDate(k);
      final pendingAfter = await storage.getPendingSyncDates();
      expect(pendingAfter, isNot(contains(k)));
    });

    test('supports backward compatibility with legacy today_steps_ keys', () async {
      final today = DateTime.now();
      final k = dayKey(today);

      SharedPreferences.setMockInitialValues({
        'today_steps_$k': 5200,
      });

      final storage = LocalDailyStatsStorage.instance;
      final stats = await storage.get(today);

      expect(stats, isNotNull);
      expect(stats!.steps, equals(5200));
      expect(stats.calories, equals((5200 * 0.04).round()));
      expect(stats.activeMinutes, equals((5200 / 100).ceil()));
    });
  });
}
