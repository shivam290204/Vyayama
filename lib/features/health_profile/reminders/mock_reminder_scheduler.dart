import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_scheduler.dart';

/// In-memory scheduler that only records what would be scheduled.
class MockReminderScheduler implements ReminderScheduler {
  final Map<String, ReminderRequest> _scheduled = <String, ReminderRequest>{};

  /// Currently "scheduled" reminders (useful for debugging and tests).
  List<ReminderRequest> get scheduled =>
      List<ReminderRequest>.unmodifiable(_scheduled.values);

  @override
  Future<void> schedule(ReminderRequest request) async {
    _scheduled[request.id] = request;
  }

  @override
  Future<void> cancel(String id) async {
    _scheduled.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    _scheduled.clear();
  }
}
