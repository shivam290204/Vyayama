import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/plan_schedule.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Expandable card for one plan day with its exercises and a start button.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.day,
    required this.library,
    this.initiallyExpanded = false,
  });

  final PlanDay day;
  final List<Exercise> library;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {for (final e in library) e.id: e};
    final minutes = estimateDayMinutes(day);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('${weekdayName(day.dayNumber)} · ${day.name}'),
        subtitle: Text(
          day.exercises.isEmpty
              ? 'No exercises'
              : '${day.exercises.length} exercises · about $minutes min',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final pe in day.exercises)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(byId[pe.exerciseId]?.name ?? 'Exercise'),
              subtitle: Text(prescriptionLabel(pe)),
              trailing: const Icon(Icons.chevron_right, semanticLabel: 'Details'),
              onTap: () => context.push(AppRoutes.exercisePath(pe.exerciseId)),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: day.exercises.isEmpty
                  ? null
                  : () => context.push(AppRoutes.workoutSessionPath(day.id)),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start workout'),
            ),
          ),
          if (day.exercises.isEmpty)
            Text(
              'This day has no exercises yet.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
