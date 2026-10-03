import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/foundation.dart';

/// One change made while adapting a plan to a user's conditions.
@immutable
class AdaptationNote {
  const AdaptationNote({
    required this.dayNumber,
    required this.originalExerciseId,
    required this.originalName,
    required this.reasonTags,
    this.replacementExerciseId,
    this.replacementName,
  });

  final int dayNumber;
  final String originalExerciseId;
  final String originalName;
  final Set<String> reasonTags;
  final String? replacementExerciseId;
  final String? replacementName;

  bool get wasReplaced => replacementExerciseId != null;

  /// Friendly, non-medical explanation for the user.
  String get message {
    final why = reasonTags.map((t) => prettyLabel(t).toLowerCase()).join(', ');
    if (wasReplaced) {
      return 'Swapped $originalName for $replacementName because '
          '$originalName may not suit your selected conditions ($why).';
    }
    return 'Removed $originalName because it may not suit your selected '
        'conditions ($why) and no gentler option was found.';
  }
}

/// A plan after adaptation plus the list of changes.
@immutable
class AdaptationResult {
  const AdaptationResult({required this.plan, required this.notes});

  final WorkoutPlan plan;
  final List<AdaptationNote> notes;

  bool get hasChanges => notes.isNotEmpty;
}

/// Spec 9.5: replaces exercises that clash with [conditionTags] by a safe
/// alternative from the same muscle group, or removes them and records why.
AdaptationResult adaptPlanForConditions(
  WorkoutPlan plan,
  List<String> conditionTags,
  List<Exercise> exerciseLibrary,
) {
  final tags = conditionTags
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();
  if (tags.isEmpty) return AdaptationResult(plan: plan, notes: const []);

  final byId = {for (final e in exerciseLibrary) e.id: e};
  final notes = <AdaptationNote>[];
  final days = <PlanDay>[];

  for (final day in plan.days) {
    final usedIds = day.exercises.map((e) => e.exerciseId).toSet();
    final kept = <PlanExercise>[];

    for (final pe in day.exercises) {
      final ex = byId[pe.exerciseId];
      final clash = ex?.conflictsWith(tags) ?? const <String>{};
      if (ex == null || clash.isEmpty) {
        kept.add(pe);
        continue;
      }
      final alt = _findAlternative(ex, tags, exerciseLibrary, usedIds);
      if (alt != null) {
        usedIds.add(alt.id);
        kept.add(pe.copyWith(exerciseId: alt.id));
      }
      notes.add(
        AdaptationNote(
          dayNumber: day.dayNumber,
          originalExerciseId: ex.id,
          originalName: ex.name,
          reasonTags: clash,
          replacementExerciseId: alt?.id,
          replacementName: alt?.name,
        ),
      );
    }

    days.add(
      day.copyWith(
        exercises: [
          for (var i = 0; i < kept.length; i++) kept[i].copyWith(sortOrder: i),
        ],
      ),
    );
  }

  return AdaptationResult(plan: plan.copyWith(days: days), notes: notes);
}

Exercise? _findAlternative(
  Exercise original,
  Set<String> tags,
  List<Exercise> library,
  Set<String> usedIds,
) {
  final candidates = library
      .where(
        (c) =>
            c.id != original.id &&
            c.muscleGroup == original.muscleGroup &&
            !usedIds.contains(c.id) &&
            c.isSafeFor(tags),
      )
      .toList();
  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final aGear = a.equipment == original.equipment ? 0 : 1;
    final bGear = b.equipment == original.equipment ? 0 : 1;
    if (aGear != bGear) return aGear.compareTo(bGear);
    final aGap = (a.met - original.met).abs();
    final bGap = (b.met - original.met).abs();
    if (aGap != bGap) return aGap.compareTo(bGap);
    return a.name.compareTo(b.name);
  });
  return candidates.first;
}
