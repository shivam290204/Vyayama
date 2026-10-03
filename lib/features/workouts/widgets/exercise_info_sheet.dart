import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:flutter/material.dart';

/// Numbered instruction list.
class ExerciseSteps extends StatelessWidget {
  const ExerciseSteps({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    '${i + 1}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: cs.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(steps[i], style: theme.textTheme.bodyLarge)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bulleted "common mistakes" list.
class ExerciseMistakes extends StatelessWidget {
  const ExerciseMistakes({super.key, required this.mistakes});

  final List<String> mistakes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in mistakes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.close_rounded,
                    size: 20,
                    color: theme.colorScheme.error,
                    semanticLabel: 'Mistake'),
                const SizedBox(width: 8),
                Expanded(child: Text(m, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet with the steps and mistakes, used during a session.
Future<void> showExerciseHowTo(BuildContext context, Exercise exercise) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(exercise.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            ExerciseSteps(steps: exercise.instructions),
            if (exercise.commonMistakes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Common mistakes', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ExerciseMistakes(mistakes: exercise.commonMistakes),
            ],
            const SizedBox(height: 8),
            Text(
              'Stop if you feel sharp pain, dizziness or chest discomfort.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    },
  );
}
