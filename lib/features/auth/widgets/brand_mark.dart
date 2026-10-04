import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Brand mark tile featuring the custom Vyayama logo asset.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 88,
    this.showBackground = true,
  });

  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!showBackground) {
      return Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Vyayama logo',
      );
    }

    return Semantics(
      image: true,
      label: 'Vyayama logo',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.1),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
