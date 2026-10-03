import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_animation.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_info_sheet.dart';
import 'package:flutter/material.dart';

/// The "work" phase: one exercise, set counter, and rep target or timer.
class SessionExerciseView extends StatelessWidget {
  const SessionExerciseView({
    super.key,
    required this.state,
    required this.onDoneSet,
  });

  final SessionState state;
  final VoidCallback onDoneSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = state.current;
    final ex = item.exercise;
    final reps = item.prescription.reps;
    final total = item.prescription.durationSec ?? 0;

    final bigText = item.timed
        ? formatClock(state.secondsLeft)
        : (reps == null ? 'Go at your pace' : '$reps reps');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Exercise ${state.index + 1} of ${state.items.length}',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(ex.name,
              textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          ExerciseAnimation(
              asset: ex.animationAsset, poses: ex.poses, label: ex.name, height: 180),
          const SizedBox(height: 16),
          Text(
            'Set ${state.setIndex + 1} of ${item.sets}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Semantics(
            label: item.timed
                ? '${state.secondsLeft} seconds left'
                : (reps == null ? 'Go at your pace' : '$reps reps'),
            child: ExcludeSemantics(
              child: Text(
                bigText,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: cs.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (item.timed && total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ((total - state.secondsLeft) / total).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          if (state.paused) ...[
            const SizedBox(height: 8),
            Text('Paused',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: cs.tertiary)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.paused ? null : onDoneSet,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.check_rounded),
            label: Text(item.timed ? 'Done early' : 'Done set'),
          ),
          TextButton.icon(
            onPressed: () => showExerciseHowTo(context, ex),
            icon: const Icon(Icons.help_outline),
            label: const Text('How to do it'),
          ),
        ],
      ),
    );
  }
}
