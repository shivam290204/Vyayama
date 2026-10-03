import 'package:flutter/material.dart';

import 'package:fitbuddy/features/auth/data/auth_repository.dart';

/// Adds a busy flag and friendly error handling to auth screen states.
mixin AuthActionMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<void> runAction(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } on AuthFailure catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
