import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottie player for an exercise demo. Shows a calm placeholder when the
/// asset is missing or fails to load.
class ExerciseAnimation extends StatelessWidget {
  const ExerciseAnimation({
    super.key,
    required this.asset,
    required this.label,
    this.height = 220,
  });

  final String? asset;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = asset;
    final fallback = _Fallback(height: height);

    return Semantics(
      image: true,
      label: '$label demonstration',
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: (path == null || path.isEmpty)
            ? fallback
            : Lottie.asset(
                path,
                fit: BoxFit.contain,
                animate: !MediaQuery.of(context).disableAnimations,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              'assets/images/demo_placeholder.png',
              height: height > 150 ? 120 : 60,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Demo coming soon',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
