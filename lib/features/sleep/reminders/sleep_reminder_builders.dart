import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';

/// Id of the bedtime (wind-down) reminder.
const String bedtimeReminderId = 'sleep:bedtime';

/// Id of the wake-up alarm reminder.
const String wakeAlarmReminderId = 'sleep:wake';

/// Gentle reminder that fires when the wind-down starts.
/// Uses Bedtime Guidance channel (not full-screen alarm).
ReminderRequest buildBedtimeReminder(SleepPlan plan, {List<int>? days}) =>
    ReminderRequest(
      id: bedtimeReminderId,
      kind: ReminderKind.bedtime,
      title: 'Time to wind down',
      body: 'Your suggested bedtime is ${plan.bedtime.format12h()}.',
      hour: plan.windDownStart.hour,
      minute: plan.windDownStart.minute,
      weekdays: days ?? const <int>[1, 2, 3, 4, 5, 6, 7],
      exact: true,
      alarmStyle: false,
    );

/// Alarm-style reminder at the suggested wake time.
/// Uses Wake Alarms channel with sound, vibration, and exact alarm scheduling.
ReminderRequest buildWakeAlarm(SleepPlan plan, {List<int>? days}) =>
    ReminderRequest(
      id: wakeAlarmReminderId,
      kind: ReminderKind.wakeAlarm,
      title: 'Good morning!',
      body: 'Time to wake up. Have a great day!',
      hour: plan.wakeTime.hour,
      minute: plan.wakeTime.minute,
      weekdays: days ?? const <int>[1, 2, 3, 4, 5, 6, 7],
      exact: true,
      alarmStyle: true,
    );
