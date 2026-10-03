import 'package:flutter/material.dart';

/// Interface for all exercise animation renderers.
abstract class ExerciseRenderer {
  /// Whether this renderer can handle the given [asset] and [poses].
  bool canHandle(String? asset, List<String> poses);

  /// Builds the widget for the exercise demonstration.
  Widget build({
    required BuildContext context,
    required String? asset,
    required List<String> poses,
    required double height,
  });
}
