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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 48,
            color: cs.primaryContainer.withValues(alpha: 0.45),
            child: Image.asset(
              exercise.characterAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.fitness_center,
                    color: cs.primary, semanticLabel: 'Exercise'),
              ),
            ),
          ),
        ),
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${prettyLabel(exercise.muscleGroup)} · ${prettyLabel(exercise.equipment)}',
        ),
        trailing: clash
            ? Tooltip(
                message: 'May not suit your health conditions',
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: cs.error,
                  semanticLabel: 'May not suit your conditions',
                ),
              )
            : const Icon(Icons.chevron_right, semanticLabel: 'Open'),
        onTap: () => context.push(AppRoutes.exercisePath(exercise.id)),
      ),
    );
  }
}
