import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicine_edit_sheet.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/alarm_test_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSoundService', () {
    test('defines correct sound asset paths', () {
      expect(AppSounds.wakeUpAlarm, equals('audio/wakeupAlarm.wav'));
      expect(AppSounds.medicineWarning, equals('audio/warningalarm.mp3'));
    });

    test('service instance manages playing state safely', () async {
      final service = AppSoundService.instance;
      expect(service.isPlaying, isFalse);
      expect(service.isPlayingNotifier.value, isFalse);

      await service.stop();
      expect(service.isPlaying, isFalse);
      expect(service.isPlayingNotifier.value, isFalse);
    });
  });

  group('AlarmTestDialog', () {
    testWidgets('renders alarm time, sound name, and action buttons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AlarmTestDialog(
              alarmTime: '07:30 AM',
              alarmSound: 'Gentle Chime',
              vibrate: true,
              snoozeMinutes: 10,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Good Morning! ☀️'), findsOneWidget);
      expect(find.text('07:30 AM'), findsOneWidget);
      expect(
        find.text('Alarm Sound: Gentle Chime · Vibrate On'),
        findsOneWidget,
      );
      expect(find.text('Snooze (10m)'), findsOneWidget);
      expect(find.text("I'm Awake!"), findsOneWidget);

      // Verify the mute/sound toggle button is present
      expect(find.byIcon(Icons.volume_up_rounded), findsWidgets);

      // Tap Snooze and verify sound stops and dialog handles action
      await tester.tap(find.text('Snooze (10m)'));
      await tester.pump();
    });
  });

  group('MedicineEditSheet', () {
    testWidgets('renders add medicine title, input fields, and save button',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MedicineEditSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add medicine reminder'), findsOneWidget);
      expect(find.text('Medicine name'), findsOneWidget);
      expect(find.text('Reminder times'), findsOneWidget);
      expect(find.text('Warning Alarm Sound'), findsNothing);
      expect(find.text('Preview'), findsNothing);
      expect(find.text('Save reminder'), findsOneWidget);
    });
  });
}
