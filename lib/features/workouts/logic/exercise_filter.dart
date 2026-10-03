import 'package:fitbuddy/features/workouts/data/exercise.dart';

/// Filters the library by search text, muscle group, equipment and
/// contraindication tags to avoid. Result is sorted by name.
List<Exercise> filterExercises(
  Iterable<Exercise> all, {
  String query = '',
  String? muscleGroup,
  String? equipment,
  Set<String> avoidTags = const <String>{},
}) {
  final q = query.trim().toLowerCase();
  final result = all.where((e) {
    if (muscleGroup != null && e.muscleGroup != muscleGroup) return false;
    if (equipment != null && e.equipment != equipment) return false;
    if (q.isNotEmpty &&
        !e.name.toLowerCase().contains(q) &&
        !e.muscleGroup.replaceAll('_', ' ').contains(q)) {
      return false;
    }
    if (avoidTags.isNotEmpty && !e.isSafeFor(avoidTags)) return false;
    return true;
  }).toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  return result;
}
