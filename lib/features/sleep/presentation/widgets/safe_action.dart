import 'package:flutter/material.dart';

/// Runs [action] and shows a friendly message if it fails.
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save. Please try again.')),
    );
    return false;
  }
}
