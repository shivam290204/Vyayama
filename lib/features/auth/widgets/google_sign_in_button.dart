import 'package:flutter/material.dart';

/// "Continue with Google" button.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.account_circle_outlined),
      label: const Text('Continue with Google'),
    );
  }
}
