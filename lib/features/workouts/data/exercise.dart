import 'package:fitbuddy/features/workouts/data/json_helpers.dart';
import 'package:flutter/foundation.dart';

/// An exercise from the library (table `exercises`, plus `common_mistakes`
/// and `met` which come from the bundled JSON).
@immutable
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.instructions,
    required this.commonMistakes,
    required this.contraindications,
    required this.met,
    this.animationAsset,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '',
      muscleGroup: (json['muscle_group'] as String?) ?? 'full_body',
      equipment: (json['equipment'] as String?) ?? 'none',
      instructions: jsonSteps(json['instructions']),
      commonMistakes: jsonStringList(json['common_mistakes']),
      contraindications: jsonStringList(json['contraindications']),
      met: (json['met'] as num?)?.toDouble() ?? 3.0,
      animationAsset: json['animation_asset'] as String?,
    );
  }

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final List<String> instructions;
  final List<String> commonMistakes;
  final List<String> contraindications;
  final double met;
  final String? animationAsset;

  /// Contraindication tags of this exercise that match [tags]
  /// (case-insensitive). Empty means no conflict.
  Set<String> conflictsWith(Iterable<String> tags) {
    final wanted = tags
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet();
    return {
      for (final c in contraindications)
        if (wanted.contains(c.toLowerCase())) c.toLowerCase(),
    };
  }

  bool isSafeFor(Iterable<String> tags) => conflictsWith(tags).isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle_group': muscleGroup,
        'equipment': equipment,
        'instructions': instructions,
        'common_mistakes': commonMistakes,
        'animation_asset': animationAsset,
        'contraindications': contraindications,
        'met': met,
      };

  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
