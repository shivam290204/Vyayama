import 'package:fitbuddy/features/workouts/data/bodyweight_workout_flow.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:flutter/material.dart';

/// The rest countdown with skip and +15 s.
class SessionRestView extends StatelessWidget {
  const SessionRestView({
    super.key,
    required this.state,
    required this.onSkip,
    required this.onAddTime,
    this.planDayId,
  });

  final SessionState state;
  final VoidCallback onSkip;
  final VoidCallback onAddTime;
  final String? planDayId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final upcoming = state.items[state.nextIndex];
    final total = state.current.restSec;
    final value =
        total <= 0 ? 0.0 : (state.secondsLeft / total).clamp(0.0, 1.0).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Rest', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Breathe and shake it out.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Semantics(
            label: 'Rest, ${state.secondsLeft} seconds left',
            child: ExcludeSemantics(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      formatClock(state.secondsLeft),
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: cs.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (state.paused) ...[
            const SizedBox(height: 12),
            Text('Paused',
                style: theme.textTheme.titleMedium?.copyWith(color: cs.tertiary)),
          ],
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final contextInfo = BodyweightWorkoutCatalog.findContext(
                planDayId: planDayId,
                exerciseId: upcoming.exercise.id,
                index: state.nextIndex,
              );
              if (contextInfo != null) {
                final (phaseColor, phaseIcon) = switch (contextInfo.phase) {
                  WorkoutSectionType.warmup => (
                      const Color(0xFFFF9800),
                      Icons.wb_sunny_rounded,
                    ),
                  WorkoutSectionType.main => (
                      const Color(0xFF00C853),
                      Icons.fitness_center_rounded,
                    ),
                  WorkoutSectionType.cooldown => (
                      const Color(0xFF00B4D8),
                      Icons.self_improvement_rounded,
                    ),
                };
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(phaseIcon, size: 13, color: phaseColor),
                      const SizedBox(width: 4),
                      Text(
                        'Up next: ${contextInfo.phase.label}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: phaseColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Text('Up next', style: theme.textTheme.labelLarge);
            },
          ),
          Text(
            upcoming.exercise.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          Text(
            'Set ${state.nextSet + 1} of ${upcoming.sets}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onSkip,
                icon: const Icon(Icons.fast_forward_rounded),
                label: const Text('Skip rest'),
              ),
              OutlinedButton.icon(
                onPressed: onAddTime,
                icon: const Icon(Icons.add),
                label: const Text('15 s'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
