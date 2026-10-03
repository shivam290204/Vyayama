import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centered icon, title, message and optional action.
class StateMessage extends StatelessWidget {
  const StateMessage({
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 56, color: scheme.outline)),
            const SizedBox(height: 16),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders loading, error, empty and data states of an [AsyncValue].
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.data,
    required this.onRetry,
    this.isEmpty,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyActionLabel,
    this.onEmptyAction,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final String? emptyActionLabel;
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => Center(
        child: Semantics(
          label: 'Loading',
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => StateMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: 'Please check your connection and try again.',
        actionLabel: 'Try again',
        onAction: onRetry,
      ),
      data: (d) => (isEmpty?.call(d) ?? false)
          ? StateMessage(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
              actionLabel: emptyActionLabel,
              onAction: onEmptyAction,
            )
          : data(d),
    );
  }
}
