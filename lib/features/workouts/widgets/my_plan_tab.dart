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
        Text(
          'Recommended for you',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My custom plans',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            mine.maybeWhen(
              data: (plans) => plans.isNotEmpty
                  ? FilledButton.tonalIcon(
                      onPressed: () => context.push(AppRoutes.planBuilder),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New plan'),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
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
    final bool isRestDay;
    if (today != null) {
      headline = 'Today: ${today.name} · ${today.exercises.length} exercises · '
          '~${estimateDayMinutes(today)} min';
      isRestDay = false;
    } else if (next != null) {
      headline = 'Today is a rest day. Next up: ${next.name} on '
          '${weekdayName(next.dayNumber)}.';
      isRestDay = true;
    } else {
      headline = 'This plan has no days yet.';
      isRestDay = false;
    }
    final startDay = today ?? next;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showMascot = constraints.maxWidth >= 480;

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: cs.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          color: cs.primaryContainer,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Opacity(
                  opacity: 0.06,
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 180,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded,
                                    size: 14, color: cs.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'ACTIVE PLAN',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: cs.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            plan.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _BadgePill(
                                icon: Icons.local_fire_department_rounded,
                                label: goalLabel(plan.goal),
                                colorScheme: cs,
                              ),
                              _BadgePill(
                                icon: Icons.speed_rounded,
                                label: prettyLabel(plan.level ?? 'beginner'),
                                colorScheme: cs,
                              ),
                              _BadgePill(
                                icon: Icons.calendar_today_rounded,
                                label: '${plan.days.length} days/week',
                                colorScheme: cs,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isRestDay
                                      ? Icons.bedtime_outlined
                                      : Icons.bolt_rounded,
                                  size: 18,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    headline,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (startDay != null)
                                FilledButton.icon(
                                  onPressed: () => context.push(
                                    AppRoutes.workoutSessionPath(startDay.id),
                                  ),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Start workout'),
                                ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor:
                                      cs.surface.withValues(alpha: 0.4),
                                ),
                                onPressed: () => context.push(
                                  AppRoutes.workoutPlanPath(plan.id),
                                ),
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 16),
                                label: const Text('View plan'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (showMascot)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Image.asset(
                          'assets/images/mascot/standing_hero.png',
                          height: 125,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
