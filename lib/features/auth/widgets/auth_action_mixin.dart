import 'package:flutter/material.dart';

import 'package:fitbuddy/features/auth/data/auth_repository.dart';

/// Adds a busy flag, inline error state, and friendly error handling to auth screen states.
mixin AuthActionMixin<T extends StatefulWidget> on State<T> {
  bool busy = false;
  String? actionError;

  void clearActionError() {
    if (actionError != null && mounted) {
      setState(() => actionError = null);
    }
  }

  Future<bool> runAction(
    Future<void> Function() action, {
    void Function(AuthFailure failure)? onAuthFailure,
  }) async {
    if (busy) return false;
    setState(() {
      busy = true;
      actionError = null;
    });
    try {
      await action();
      return true;
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() => actionError = error.message);
      }
      onAuthFailure?.call(error);
      showMessage(error.message);
      return false;
    } catch (_) {
      const msg = 'Something went wrong. Please try again.';
      if (mounted) {
        setState(() => actionError = msg);
      }
      showMessage(msg);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showMessage(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
        ),
      );
  }
}
