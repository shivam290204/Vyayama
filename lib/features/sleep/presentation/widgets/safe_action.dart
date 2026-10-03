import 'package:flutter/material.dart';

/// Runs [action] and shows a friendly message if it fails.
Future<void> runSafely(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not save. Please try again.')),
    );
  }
}
