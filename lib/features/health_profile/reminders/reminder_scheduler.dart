import 'package:fitbuddy/core/services/schedule_result.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';

/// Schedules local reminders.
///
/// Implemented with `flutter_local_notifications` and `timezone`,
/// requests exact-alarm permission on Android, and re-schedules after reboot.
abstract class ReminderScheduler {
  /// Schedules (or replaces) the reminder with the same id and returns the result.
  Future<ScheduleResult> schedule(ReminderRequest request);

  /// Cancels the reminder with [id].
  Future<void> cancel(String id);

  /// Cancels every reminder.
  Future<void> cancelAll();
}
