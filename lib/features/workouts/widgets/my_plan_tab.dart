import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/plan_schedule.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/plan_card.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// "My Plan" tab: recommended plan with today's workout, and custom plans.
class MyPlanTab extends ConsumerWidget {
  const MyPlanTab({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutPlan plan,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this plan?'),
        content: Text('"${plan.title}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(myPlansProvider.notifier).delete(plan.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recommended = ref.watch(defaultPlanProvider);
    final mine = ref.watch(myPlansProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('Recommended for you', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        recommended.when(
          loading: () => const WorkoutLoading(),
          error: (e, _) => WorkoutErrorView(
            onRetry: () => ref.invalidate(defaultPlanProvider),
          ),
          data: (plan) => plan == null
              ? const WorkoutMessageView(
                  icon: Icons.fitness_center,
                  title: 'No plans yet',
                  message: 'Browse plans or build your own.',
                )
              : _RecommendedCard(plan: plan),
        ),
        const SizedBox(height: 24),
        Text('My custom plans', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        mine.when(
          loading: () => const WorkoutLoading(),
          error: (e, _) => WorkoutErrorView(
            onRetry: () => ref.invalidate(myPlansProvider),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return WorkoutMessageView(
                icon: Icons.edit_note_rounded,
                title: 'Build your own plan',
                message: 'Pick exercises, sets and days that fit your week.',
                actionLabel: 'Create plan',
                onAction: () => context.push(AppRoutes.planBuilder),
              );
            }
            return Column(
              children: [
                for (final p in plans)
                  PlanCard(
                    plan: p,
                    onTap: () => context.push(AppRoutes.workoutPlanPath(p.id)),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Plan options',
                      onSelected: (v) {
                        if (v == 'edit') {
                          context.push('${AppRoutes.planBuilder}?planId=${p.id}');
                        } else {
                          _confirmDelete(context, ref, p);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'General wellness information, not medical advice. Check with a '
          'doctor before starting a new exercise program.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = plan.dayForWeekday(DateTime.now().weekday);
    final next = nextWorkoutDay(plan);

    final String headline;
    if (today != null) {
      headline = 'Today: ${today.name} · ${today.exercises.length} exercises · '
          'about ${estimateDayMinutes(today)} min';
    } else if (next != null) {
      headline = 'Today is a rest day. Next up: ${next.name} on '
          '${weekdayName(next.dayNumber)}.';
    } else {
      headline = 'This plan has no days yet.';
    }
    final startDay = today ?? next;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: cs.onPrimaryContainer)),
            Text(
              '${goalLabel(plan.goal)} · ${prettyLabel(plan.level ?? 'beginner')}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Text(headline,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: cs.onPrimaryContainer)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (startDay != null)
                  FilledButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.workoutSessionPath(startDay.id)),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start workout'),
                  ),
                OutlinedButton(
                  onPressed: () =>
                      context.push(AppRoutes.workoutPlanPath(plan.id)),
                  child: const Text('View plan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
