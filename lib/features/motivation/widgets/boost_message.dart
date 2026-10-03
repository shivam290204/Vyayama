import 'package:flutter/material.dart';

/// Centered icon and message for empty and error states.
class BoostMessage extends StatelessWidget {
  /// Creates the message. A non-null [onRetry] shows a "Try again" button.
  const BoostMessage({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
  });

  /// Icon above the text.
  final IconData icon;

  /// Message text.
  final String text;

  /// Called by the retry button.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.primary, semanticLabel: text),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
