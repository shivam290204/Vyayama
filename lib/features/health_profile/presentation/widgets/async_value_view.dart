import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a loading indicator, a friendly error with retry, or [builder].
class AsyncValueView<T> extends StatelessWidget {
  /// Creates the view.
  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loadingHeight = 120,
  });

  /// The async value to display.
  final AsyncValue<T> value;

  /// Builds the content once data is available.
  final Widget Function(T data) builder;

  /// Called when the user taps "Try again".
  final VoidCallback? onRetry;

  /// Height reserved while loading.
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => SizedBox(
        height: loadingHeight,
        child: const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Loading'),
        ),
      ),
      error: (error, stack) => _ErrorBox(onRetry: onRetry),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.error_outline,
              color: scheme.onErrorContainer,
              semanticLabel: 'Error',
            ),
            const SizedBox(height: 8),
            Text(
              'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
