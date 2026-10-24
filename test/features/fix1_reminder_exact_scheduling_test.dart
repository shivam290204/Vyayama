import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_builders.dart';
import 'package:fitbuddy/features/settings/screens/notification_diagnostics_screen.dart';
import 'package:fitbuddy/features/sleep/domain/day_time.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/reminders/sleep_reminder_builders.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fix 1: Exact Meal & Bedtime Reminders Verification', () {
    test('buildMealReminder sets exact: true to avoid Android Doze delay', () {
      const reminder = MealReminder(
        enabled: true,
        time: TimeOfDay(hour: 8, minute: 30),
      );

      final req = buildMealReminder(MealSlot.breakfast, reminder);

      expect(req.exact, true, reason: 'Meal reminders must request exact alarm mode');
      expect(req.title, 'Breakfast time');
      expect(req.hour, 8);
      expect(req.minute, 30);
    });

    test('buildBedtimeReminder sets exact: true to avoid bedtime wind-down delay', () {
      final plan = SleepPlan(
        bedtime: DayTime(22, 30),
        wakeTime: DayTime(6, 30),
        sleepMinutes: 480,
        windDownStart: DayTime(21, 30),
      );

      final req = buildBedtimeReminder(plan);

      expect(req.exact, true, reason: 'Bedtime reminders must request exact alarm mode');
      expect(req.title, 'Time to wind down');
      expect(req.hour, 21);
      expect(req.minute, 30);
    });
  });

  group('Fix 1: Samsung Guide & Exact Alarm In-App Prompt UI Tests', () {
    testWidgets('renders Samsung One UI Battery Guide on diagnostics screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: NotificationDiagnosticsScreen(),
          ),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(NotificationDiagnosticsScreen), findsOneWidget);

      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        expect(find.text('Samsung One UI Battery Guide'), findsOneWidget);
        expect(find.text('Set Battery to "Unrestricted"'), findsOneWidget);
        expect(find.text('Add to "Never auto-sleeping apps"'), findsOneWidget);
      }
    });
  });
}
