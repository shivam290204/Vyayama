import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:flutter/material.dart';

/// Icon for a team type.
IconData teamTypeIcon(TeamType type) => switch (type) {
      TeamType.running => Icons.directions_run,
      TeamType.workout => Icons.fitness_center,
      TeamType.walking => Icons.directions_walk,
    };
