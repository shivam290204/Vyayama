import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:flutter/material.dart';

/// Runs [action] and shows a friendly message if it fails, with direct action buttons if permission is required.
/// Returns true if the action completed successfully, false otherwise.
Future<bool> runSafely(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (e, st) {
    debugPrint('runSafely caught: $e\n$st');
    if (!context.mounted) return false;
    final message = e.toString().replaceAll('Exception: ', '').trim();
    final isExactAlarmError =
        message.contains('Exact alarm') || message.contains('Alarms & Reminders');
    final isNotifError = message.contains('Notification permission');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.isNotEmpty ? message : 'Could not save. Please try again.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: isExactAlarmError
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.amberAccent,
                onPressed: () =>
                    NotificationService.instance.openExactAlarmSettings(),
              )
            : (isNotifError
                ? SnackBarAction(
                    label: 'Enable',
                    textColor: Colors.amberAccent,
                    onPressed: () => NotificationService.instance
                        .requestNotificationPermission(),
                  )
                : null),
      ),
    );
    return false;
  }
}
