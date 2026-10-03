import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/contraindication_chips.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_animation.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_info_sheet.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/workouts/exercise/:id`: animation, instructions, mistakes and warnings.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseByIdProvider(exerciseId));
    final tags = ref.watch(selectedConditionTagsProvider);

    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const WorkoutLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: WorkoutErrorView(
          onRetry: () => ref.invalidate(exerciseByIdProvider(exerciseId)),
        ),
      ),
      data: (exercise) {
        if (exercise == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const WorkoutMessageView(
              icon: Icons.search_off_rounded,
              title: 'Exercise not found',
            ),
          );
        }
        return _Body(exercise: exercise, userTags: tags);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.exercise, required this.userTags});

  final Exercise exercise;
  final List<String> userTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final clash = exercise.conflictsWith(userTags);

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExerciseAnimation(
            asset: exercise.animationAsset,
            poses: exercise.poses,
            label: exercise.name,
            height: 240,
          ),
          const SizedBox(height: 16),
          Text(exercise.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                avatar: const Icon(Icons.accessibility_new, size: 18),
                label: Text(prettyLabel(exercise.muscleGroup)),
              ),
              Chip(
                avatar: const Icon(Icons.fitness_center, size: 18),
                label: Text(prettyLabel(exercise.equipment)),
              ),
            ],
          ),
          if (clash.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: cs.onErrorContainer, semanticLabel: 'Warning'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This exercise may not suit your selected conditions '
                        '(${clash.map((t) => prettyLabel(t).toLowerCase()).join(', ')}). '
                        'Please check with your doctor or choose a gentler option.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('How to do it', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ExerciseSteps(steps: exercise.instructions),
          if (exercise.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Common mistakes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ExerciseMistakes(mistakes: exercise.commonMistakes),
          ],
          if (exercise.contraindications.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Take extra care if you have issues with',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ContraindicationChips(
              tags: exercise.contraindications,
              highlight: clash,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'General wellness information, not medical advice. Consult a '
            'qualified doctor before starting any exercise program, and stop '
            'if you feel pain, dizziness or chest discomfort.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
