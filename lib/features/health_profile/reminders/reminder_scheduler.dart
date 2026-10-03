import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';

/// Schedules local reminders.
///
/// Antigravity: implement with `flutter_local_notifications` and `timezone`,
/// request exact-alarm permission on Android, and re-schedule after reboot.
abstract class ReminderScheduler {
  /// Schedules (or replaces) the reminder with the same id.
  Future<void> schedule(ReminderRequest request);

  /// Cancels the reminder with [id].
  Future<void> cancel(String id);

  /// Cancels every reminder.
  Future<void> cancelAll();
}
