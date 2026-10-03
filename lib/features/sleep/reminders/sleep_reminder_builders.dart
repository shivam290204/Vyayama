import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';

/// Id of the bedtime (wind-down) reminder.
const String bedtimeReminderId = 'sleep:bedtime';

/// Id of the wake-up alarm reminder.
const String wakeAlarmReminderId = 'sleep:wake';

/// Reminder that fires when the wind-down starts.
ReminderRequest buildBedtimeReminder(SleepPlan plan) => ReminderRequest(
      id: bedtimeReminderId,
      kind: ReminderKind.bedtime,
      title: 'Time to wind down',
      body: 'Your suggested bedtime is ${plan.bedtime.format12h()}.',
      hour: plan.windDownStart.hour,
      minute: plan.windDownStart.minute,
      exact: true,
    );

/// Alarm-style reminder at the suggested wake time.
ReminderRequest buildWakeAlarm(SleepPlan plan) => ReminderRequest(
      id: wakeAlarmReminderId,
      kind: ReminderKind.wakeAlarm,
      title: 'Good morning!',
      body: 'Time to wake up. Have a great day!',
      hour: plan.wakeTime.hour,
      minute: plan.wakeTime.minute,
      exact: true,
      alarmStyle: true,
    );
