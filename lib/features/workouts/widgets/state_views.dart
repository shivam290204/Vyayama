import 'package:flutter/material.dart';

/// Centered progress indicator.
class WorkoutLoading extends StatelessWidget {
  const WorkoutLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          label: 'Loading',
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Icon, title, optional message and optional action. Used for empty states.
class WorkoutMessageView extends StatelessWidget {
  const WorkoutMessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.primary, semanticLabel: title),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly error state with a retry button.
class WorkoutErrorView extends StatelessWidget {
  const WorkoutErrorView({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return WorkoutMessageView(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: 'We could not load this. Please try again.',
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}
