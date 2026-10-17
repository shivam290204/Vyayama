import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_scheduler.dart';

/// Computes a stable, deterministic 31-bit integer hash from a string ID
/// that remains identical across process restarts, app launches, and Dart VMs.
int stableNotificationId(String id) {
  var hash = 0x811c9dc5;
  for (var i = 0; i < id.length; i++) {
    hash ^= id.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

/// Schedules real local notifications using [NotificationService].
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler({NotificationService? service})
      : _service = service ?? NotificationService.instance;

  final NotificationService _service;

  @override
  Future<void> schedule(ReminderRequest request) async {
    final intId = stableNotificationId(request.id);
    final channelId = switch (request.kind) {
      ReminderKind.medicine => NotificationService.medicineChannelId,
      ReminderKind.meal => NotificationService.mealsChannelId,
      ReminderKind.bedtime => NotificationService.sleepChannelId,
      ReminderKind.wakeAlarm => NotificationService.wakeAlarmChannelId,
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
      weekdays: request.weekdays,
      channelId: channelId,
      channelName: channelName,
      exact: request.exact,
      alarmStyle: request.alarmStyle,
      payload: '${request.kind.name}|${request.id}|${request.title}|${request.body}',
    );
  }

  @override
  Future<void> cancel(String id) async {
    await _service.cancel(stableNotificationId(id));
  }

  @override
  Future<void> cancelAll() async {
    await _service.cancelAll();
  }
}
