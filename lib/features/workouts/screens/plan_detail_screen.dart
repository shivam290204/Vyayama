import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';
import 'package:fitbuddy/features/workouts/logic/plan_schedule.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/adaptation_notes_card.dart';
import 'package:fitbuddy/features/workouts/widgets/day_card.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:fitbuddy/features/workouts/widgets/weekly_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/workouts/plan/:id`: weekly schedule, day cards and a start button.
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adaptedPlanProvider(planId));
    final library = ref.watch(exerciseLibraryProvider).maybeWhen(
          data: (d) => d,
          orElse: () => const <Exercise>[],
        );
    final tags = ref.watch(selectedConditionTagsProvider);

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const WorkoutLoading(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: WorkoutErrorView(
          onRetry: () => ref.invalidate(adaptedPlanProvider(planId)),
        ),
      ),
      data: (result) {
        if (result == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const WorkoutMessageView(
              icon: Icons.search_off_rounded,
              title: 'Plan not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        return _PlanBody(result: result, library: library, hasConditions: tags.isNotEmpty);
      },
    );
  }
}

class _PlanBody extends StatelessWidget {
  const _PlanBody({
    required this.result,
    required this.library,
    required this.hasConditions,
  });

  final AdaptationResult result;
  final List<Exercise> library;
  final bool hasConditions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final WorkoutPlan plan = result.plan;
    final startDay = nextWorkoutDay(plan);
    final today = DateTime.now().weekday;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.title),
        actions: [
          if (!plan.isSystem)
            IconButton(
              tooltip: 'Edit plan',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('${AppRoutes.planBuilder}?planId=${plan.id}'),
            ),
        ],
      ),
      body: plan.days.isEmpty
          ? const WorkoutMessageView(
              icon: Icons.event_busy_outlined,
              title: 'No days in this plan',
              message: 'Edit the plan to add workout days.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text(goalLabel(plan.goal))),
                    Chip(label: Text(prettyLabel(plan.level ?? 'beginner'))),
                    Chip(label: Text('${plan.days.length} days a week')),
                  ],
                ),
                const SizedBox(height: 16),
                Text('This week', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                WeeklyStrip(plan: plan),
                const SizedBox(height: 16),
                if (result.hasChanges) ...[
                  AdaptationNotesCard(notes: result.notes),
                  const SizedBox(height: 16),
                ] else if (hasConditions) ...[
                  Text(
                    'Please consult your doctor before starting a program.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Workout days', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final d in plan.days)
                  DayCard(
                    day: d,
                    library: library,
                    initiallyExpanded: d.dayNumber == today,
                  ),
                const SizedBox(height: 8),
                Text(
                  'General wellness information, not medical advice. Stop if '
                  'you feel pain, dizziness or chest discomfort.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
      bottomNavigationBar: startDay == null || startDay.exercises.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.workoutSessionPath(startDay.id)),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    startDay.dayNumber == today
                        ? 'Start workout'
                        : 'Start workout: ${startDay.name}',
                  ),
                ),
              ),
            ),
    );
  }
}
