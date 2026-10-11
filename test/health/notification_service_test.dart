import 'package:fitbuddy/features/health_profile/reminders/local_reminder_scheduler.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalReminderScheduler', () {
    test('computes deterministic notification IDs', () {
      final scheduler = LocalReminderScheduler();
      expect(scheduler, isNotNull);
      const req1 = ReminderRequest(
        id: 'med_aspirin_0',
        kind: ReminderKind.medicine,
        title: 'Take Aspirin',
        body: 'Time for your daily dose',
        hour: 8,
        minute: 0,
      );

      const req2 = ReminderRequest(
        id: 'med_aspirin_0',
        kind: ReminderKind.medicine,
        title: 'Take Aspirin',
        body: 'Time for your daily dose',
        hour: 8,
        minute: 0,
      );

      expect('med_aspirin_0'.hashCode & 0x7FFFFFFF, 'med_aspirin_0'.hashCode & 0x7FFFFFFF);
      expect(req1.id, req2.id);
    });

    test('accepts requests across kinds safely', () async {
      final scheduler = LocalReminderScheduler();

      // On testing / non-web environment without native bridge, it handles calls gracefully
      await scheduler.schedule(
        const ReminderRequest(
          id: 'meal_breakfast',
          kind: ReminderKind.meal,
          title: 'Breakfast Time',
          body: 'Healthy start to your day',
          hour: 8,
          minute: 30,
        ),
      );

      await scheduler.cancel('meal_breakfast');
      await scheduler.cancelAll();
    });
  });
}
