import 'package:flutter/material.dart';

/// Exercise tags allowed by `snaps.activity_type`.
enum ActivityType {
  workout,
  running,
  yoga,
  walking,
  cycling,
  gym,
  stretching,
  sports,
  otherExercise;

  /// Value stored in the database column.
  String get dbValue => this == otherExercise ? 'other_exercise' : name;

  String get label => switch (this) {
        workout => 'Workout',
        running => 'Running',
        yoga => 'Yoga',
        walking => 'Walking',
        cycling => 'Cycling',
        gym => 'Gym',
        stretching => 'Stretching',
        sports => 'Sports',
        otherExercise => 'Exercise',
      };

  IconData get icon => switch (this) {
        workout => Icons.sports_gymnastics,
        running => Icons.directions_run,
        yoga => Icons.self_improvement,
        walking => Icons.directions_walk,
        cycling => Icons.directions_bike,
        gym => Icons.fitness_center,
        stretching => Icons.accessibility_new,
        sports => Icons.sports_soccer,
        otherExercise => Icons.bolt,
      };

  static ActivityType fromDb(String? v) => ActivityType.values.firstWhere(
        (e) => e.dbValue == v,
        orElse: () => ActivityType.otherExercise,
      );

  /// The eight tags shown as chips in the preview screen.
  static const List<ActivityType> selectable = [
    workout,
    running,
    yoga,
    walking,
    cycling,
    gym,
    stretching,
    sports,
  ];
}
