import 'package:flutter/material.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/exercise_renderer.dart';

class FallbackRenderer implements ExerciseRenderer {
  const FallbackRenderer();

  @override
  bool canHandle(String? asset, List<String> poses) => true;

  @override
  Widget build({
    required BuildContext context,
    required String? asset,
    required List<String> poses,
    required double height,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.fitness_center,
              size: height > 150 ? 64 : 40,
              color: color,
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
