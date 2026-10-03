import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/material.dart';

/// Summary card for a plan.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.onTap,
    this.trailing,
  });

  final WorkoutPlan plan;
  final VoidCallback onTap;
  final Widget? trailing;

  IconData get _icon => switch (plan.goal) {
        'lose' => Icons.local_fire_department_rounded,
        'gain' => Icons.fitness_center,
        _ => Icons.self_improvement,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: Icon(_icon,
                    color: cs.onPrimaryContainer,
                    semanticLabel: goalLabel(plan.goal)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.days.length} days a week · '
                      '${prettyLabel(plan.level ?? 'beginner')} · '
                      '${goalLabel(plan.goal)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right, semanticLabel: 'Open'),
            ],
          ),
        ),
      ),
    );
  }
}
