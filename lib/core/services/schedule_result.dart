/// Status of a local reminder or alarm scheduling request.
enum ScheduleStatus {
  /// Exact alarm scheduled using exactAllowWhileIdle.
  exactAlarmScheduled,

  /// Inexact notification scheduled (acceptable for bedtime guidance and meal nudges).
  inexactNotificationScheduled,

  /// Post notification permission denied by user or OS.
  notificationPermissionDenied,

  /// Exact alarm permission (SCHEDULE_EXACT_ALARM) denied.
  exactAlarmPermissionDenied,

  /// Target notification channel is disabled in Android settings.
  channelDisabled,

  /// Notification service initialization failed.
  initializationFailed,

  /// Platform or native exception during scheduling.
  nativeException,
}

/// Rich result returned by scheduling operations, avoiding swallowed errors.
class ScheduleResult {
  const ScheduleResult({
    required this.status,
    this.errorMessage,
    this.notificationId,
  });

  const ScheduleResult.success({
    required bool exact,
    this.notificationId,
  })  : status = exact
            ? ScheduleStatus.exactAlarmScheduled
            : ScheduleStatus.inexactNotificationScheduled,
        errorMessage = null;

  const ScheduleResult.failure(
    this.status, {
    this.errorMessage,
    this.notificationId,
  });

  final ScheduleStatus status;
  final String? errorMessage;
  final int? notificationId;

  bool get isSuccess =>
      status == ScheduleStatus.exactAlarmScheduled ||
      status == ScheduleStatus.inexactNotificationScheduled;

  bool get isExact => status == ScheduleStatus.exactAlarmScheduled;

  String get userFriendlyMessage {
    switch (status) {
      case ScheduleStatus.exactAlarmScheduled:
        return 'Exact alarm scheduled successfully.';
      case ScheduleStatus.inexactNotificationScheduled:
        return 'Reminder notification scheduled.';
      case ScheduleStatus.notificationPermissionDenied:
        return 'Notification permission is required to deliver reminders.';
      case ScheduleStatus.exactAlarmPermissionDenied:
        return 'Exact alarm permission required. Please grant "Alarms & Reminders" in system settings.';
      case ScheduleStatus.channelDisabled:
        return 'The notification channel is disabled in device settings.';
      case ScheduleStatus.initializationFailed:
        return 'Notification service could not be initialized.';
      case ScheduleStatus.nativeException:
        return errorMessage != null && errorMessage!.isNotEmpty
            ? 'Failed to schedule alarm: $errorMessage'
            : 'A system error occurred while scheduling the alarm.';
    }
  }

  @override
  String toString() =>
      'ScheduleResult(status: $status, id: $notificationId, error: $errorMessage)';
}
