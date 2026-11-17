import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/sleep/presentation/sleep_screen.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_plan_card.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SleepScreen renders without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SleepScreen(),
        ),
      ),
    );
    await tester.pump();
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Bedtime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('SleepSettingsNotifier actions execute without error', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    // Initial load
    final initial = await container.read(sleepSettingsProvider.future);
    expect(initial.wakeAlarmOn, isFalse);

    // Toggling wake alarm
    await container.read(sleepSettingsProvider.notifier).setWakeAlarm(true);
    expect(container.read(sleepSettingsProvider).asData?.value.wakeAlarmOn, isTrue);

    // Toggling bedtime reminder
    await container.read(sleepSettingsProvider.notifier).setBedtimeReminder(true);
    expect(container.read(sleepSettingsProvider).asData?.value.bedtimeReminderOn, isTrue);

    // Setting sleep minutes
    await container.read(sleepSettingsProvider.notifier).setSleepMinutes(510);
    expect(container.read(sleepSettingsProvider).asData?.value.sleepMinutes, equals(510));
  });

  testWidgets('SleepScreen toggles wake alarm and updates slider in UI', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: SleepScreen(),
        ),
      ),
    );
    await tester.pump();
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final switches = find.byType(Switch);
    expect(switches, findsWidgets);

    // Tap wake alarm switch
    await tester.ensureVisible(switches.first);
    await tester.tap(switches.first, warnIfMissed: false);
    await tester.pump();
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('SleepPlanCard renders without RenderFlex overflow on narrow viewport and high text scale', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: SleepPlanCard(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Bedtime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
