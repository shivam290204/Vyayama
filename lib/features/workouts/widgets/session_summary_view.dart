import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:flutter/material.dart';

/// Finish screen: duration, estimated calories and a friendly message.
class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({
    super.key,
    required this.summary,
    required this.onDone,
  });

  final SessionSummary summary;
  final VoidCallback onDone;

  String get _message {
    if (summary.exercisesCompleted == 0) {
      return 'Every start counts. Come back whenever you are ready!';
    }
    if (summary.exercisesCompleted == summary.totalExercises) {
      return 'Great job! You showed up and finished strong.';
    }
    return 'Nice effort! You did ${summary.exercisesCompleted} of '
        '${summary.totalExercises} exercises, and that is real progress.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Icon(Icons.emoji_events_rounded,
              size: 72, color: cs.primary, semanticLabel: 'Workout finished'),
          const SizedBox(height: 12),
          Text('Workout finished',
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_message,
              style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.timer_outlined,
                  value: '${summary.durationMin}',
                  label: 'minutes',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  icon: Icons.local_fire_department_outlined,
                  value: '~${summary.calories}',
                  label: 'kcal (estimate)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  icon: Icons.check_circle_outline,
                  value: '${summary.exercisesCompleted}/${summary.totalExercises}',
                  label: 'exercises',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Calories are a rough estimate based on activity level and your weight.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onDone,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Semantics(
          label: '$value $label',
          child: ExcludeSemantics(
            child: Column(
              children: [
                Icon(icon, color: cs.onSecondaryContainer),
                const SizedBox(height: 4),
                Text(value,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: cs.onSecondaryContainer)),
                Text(label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSecondaryContainer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
