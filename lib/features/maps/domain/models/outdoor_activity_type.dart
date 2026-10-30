import 'package:flutter/material.dart';

/// Supported outdoor GPS activity types.
enum OutdoorActivityType {
  walking,
  running,
  hiking;

  String get label {
    switch (this) {
      case OutdoorActivityType.walking:
        return 'Walk';
      case OutdoorActivityType.running:
        return 'Run';
      case OutdoorActivityType.hiking:
        return 'Hike';
    }
  }

  IconData get icon {
    switch (this) {
      case OutdoorActivityType.walking:
        return Icons.directions_walk_rounded;
      case OutdoorActivityType.running:
        return Icons.directions_run_rounded;
      case OutdoorActivityType.hiking:
        return Icons.hiking_rounded;
    }
  }

  /// Estimated MET (Metabolic Equivalent of Task) for calorie estimations.
  double get met {
    switch (this) {
      case OutdoorActivityType.walking:
        return 3.5;
      case OutdoorActivityType.running:
        return 8.0;
      case OutdoorActivityType.hiking:
        return 6.0;
    }
  }

  static OutdoorActivityType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'run':
      case 'running':
        return OutdoorActivityType.running;
      case 'hike':
      case 'hiking':
        return OutdoorActivityType.hiking;
      case 'walk':
      case 'walking':
      default:
        return OutdoorActivityType.walking;
    }
  }
}

