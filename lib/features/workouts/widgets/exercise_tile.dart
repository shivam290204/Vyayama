import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A library row. Shows a warning icon if the exercise clashes with
/// [userTags].
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({
    super.key,
    required this.exercise,
    this.userTags = const <String>[],
  });

  final Exercise exercise;
  final List<String> userTags;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final clash = exercise.conflictsWith(userTags).isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        minVerticalPadding: 12,
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          child: Icon(Icons.fitness_center,
              color: cs.onPrimaryContainer, semanticLabel: 'Exercise'),
        ),
        title: Text(exercise.name),
        subtitle: Text(
          '${prettyLabel(exercise.muscleGroup)} · ${prettyLabel(exercise.equipment)}',
        ),
        trailing: clash
            ? Icon(Icons.warning_amber_rounded,
                color: cs.error, semanticLabel: 'May not suit your conditions')
            : const Icon(Icons.chevron_right, semanticLabel: 'Open'),
        onTap: () => context.push(AppRoutes.exercisePath(exercise.id)),
      ),
    );
  }
}
