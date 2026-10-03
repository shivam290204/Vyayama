import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Simple logo tile used on auth screens.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      image: true,
      label: 'Vyayama logo',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Icon(
          Icons.fitness_center_rounded,
          size: size * 0.5,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
