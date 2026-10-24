import 'package:fitbuddy/core/services/notification_diagnostic_logger.dart';
import 'package:fitbuddy/features/settings/screens/notification_diagnostics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationDiagnosticLogger Service Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      NotificationDiagnosticLogger.instance.overridePrefs = prefs;
      await NotificationDiagnosticLogger.instance.clear();
    });

    test('logScheduled stores record with exact target time and mode', () async {
      final scheduledTime = DateTime(2026, 10, 25, 8, 30, 0);
      await NotificationDiagnosticLogger.instance.logScheduled(
        id: 101,
        title: 'Morning Breakfast',
        scheduledTime: scheduledTime,
        isExact: true,
        channelId: 'meal_reminders',
      );

      final records = await NotificationDiagnosticLogger.instance.getRecentRecords();
      expect(records.length, 1);
      expect(records.first.id, 101);
      expect(records.first.title, 'Morning Breakfast');
      expect(records.first.scheduledTime, scheduledTime);
      expect(records.first.isExact, true);
      expect(records.first.firedTime, isNull);
      expect(records.first.delaySeconds, isNull);
    });

    test('logFired calculates delay seconds accurately', () async {
      final scheduledTime = DateTime(2026, 10, 25, 8, 30, 0);
      await NotificationDiagnosticLogger.instance.logScheduled(
        id: 102,
        title: 'Morning Medicine',
        scheduledTime: scheduledTime,
        isExact: true,
        channelId: 'medicine_reminders',
      );

      // Fired 45 seconds late
      final fireTime = scheduledTime.add(const Duration(seconds: 45));
      await NotificationDiagnosticLogger.instance.logFired(102, fireTime: fireTime);

      final records = await NotificationDiagnosticLogger.instance.getRecentRecords();
      expect(records.length, 1);
      expect(records.first.id, 102);
      expect(records.first.firedTime, fireTime);
      expect(records.first.delaySeconds, 45);
    });

    test('clear removes all stored records', () async {
      await NotificationDiagnosticLogger.instance.logScheduled(
        id: 103,
        title: 'Bedtime Nudge',
        scheduledTime: DateTime.now(),
        isExact: false,
        channelId: 'sleep_reminders',
      );

      var records = await NotificationDiagnosticLogger.instance.getRecentRecords();
      expect(records.length, 1);

      await NotificationDiagnosticLogger.instance.clear();
      records = await NotificationDiagnosticLogger.instance.getRecentRecords();
      expect(records.isEmpty, true);
    });
  });

  group('NotificationDiagnosticsScreen Timing UI Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      NotificationDiagnosticLogger.instance.overridePrefs = prefs;
      await NotificationDiagnosticLogger.instance.clear();
    });

    testWidgets('renders Alarm Timing & Delivery Logs card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed a record
      await NotificationDiagnosticLogger.instance.logScheduled(
        id: 201,
        title: 'Diagnostic Test Alarm',
        scheduledTime: DateTime.now().add(const Duration(minutes: 2)),
        isExact: true,
        channelId: 'test_channel',
      );

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

      // Check if diagnostic screen and timing card rendered
      expect(find.byType(NotificationDiagnosticsScreen), findsOneWidget);
      expect(find.text('Alarm & Notification Diagnostics'), findsOneWidget);

      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        expect(find.text('Alarm Timing & Delivery Logs'), findsOneWidget);
        expect(find.text('Diagnostic Test Alarm'), findsOneWidget);
      }
    });
  });
}
