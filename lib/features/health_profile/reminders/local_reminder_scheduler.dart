import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_scheduler.dart';

/// Schedules real local notifications using [NotificationService].
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({NotificationService? service})
      : _service = service ?? NotificationService.instance;

  final NotificationService _service;

  int _notificationId(String id) => id.hashCode & 0x7FFFFFFF;

  @override
  Future<void> schedule(ReminderRequest request) async {
    final intId = _notificationId(request.id);
    final channelId = switch (request.kind) {
      ReminderKind.medicine => 'vyayama_medicine',
      ReminderKind.meal => 'vyayama_meals',
      ReminderKind.bedtime => 'vyayama_sleep',
      ReminderKind.wakeAlarm => 'vyayama_alarm',
    };

    final channelName = switch (request.kind) {
      ReminderKind.medicine => 'Medicine Reminders',
      ReminderKind.meal => 'Meal Reminders',
      ReminderKind.bedtime => 'Bedtime Guidance',
      ReminderKind.wakeAlarm => 'Wake Alarms',
    };

    await _service.scheduleDaily(
      id: intId,
      title: request.title,
      body: request.body,
      hour: request.hour,
      minute: request.minute,
      channelId: channelId,
      channelName: channelName,
      exact: request.exact,
      alarmStyle: request.alarmStyle,
    );
  }

  @override
  Future<void> cancel(String id) async {
    await _service.cancel(_notificationId(id));
  }

  @override
  Future<void> cancelAll() async {
    await _service.cancelAll();
  }
}
