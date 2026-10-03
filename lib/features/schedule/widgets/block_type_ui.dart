import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:flutter/material.dart';

/// Icon and label for each [BlockType].
extension BlockTypeUi on BlockType {
  /// Icon shown on cards and chips.
  IconData get icon => switch (this) {
        BlockType.workout => Icons.fitness_center,
        BlockType.meal => Icons.restaurant,
        BlockType.medicine => Icons.medication_outlined,
        BlockType.sleep => Icons.bedtime_outlined,
        BlockType.wake => Icons.wb_sunny_outlined,
        BlockType.custom => Icons.event_note_outlined,
      };

  /// Human-readable name.
  String get label => switch (this) {
        BlockType.workout => 'Workout',
        BlockType.meal => 'Meal',
        BlockType.medicine => 'Medicine reminder',
        BlockType.sleep => 'Bedtime',
        BlockType.wake => 'Wake up',
        BlockType.custom => 'Custom',
      };
}

/// Icon and label for each [BlockStatus].
extension BlockStatusUi on BlockStatus {
  /// Icon shown next to the status text.
  IconData get icon => switch (this) {
        BlockStatus.upcoming => Icons.schedule,
        BlockStatus.done => Icons.check_circle,
        BlockStatus.missed => Icons.alarm_off,
        BlockStatus.skipped => Icons.skip_next,
        BlockStatus.passed => Icons.history,
      };

  /// Human-readable name.
  String get label => switch (this) {
        BlockStatus.upcoming => 'Upcoming',
        BlockStatus.done => 'Done',
        BlockStatus.missed => 'Missed',
        BlockStatus.skipped => 'Skipped',
        BlockStatus.passed => 'Time passed',
      };
}
