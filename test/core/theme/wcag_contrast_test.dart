import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/core/theme/app_theme.dart';

double _relativeLuminance(Color color) {
  double adjust(double channel) {
    return channel <= 0.04045
        ? channel / 12.92
        : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = adjust(color.r);
  final g = adjust(color.g);
  final b = adjust(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA Contrast Compliance (STEP B)', () {
    test('Dark text on orange buttons meets WCAG AA (>= 4.5:1)', () {
      final darkTheme = AppTheme.dark(useGoogleFonts: false);
      final lightTheme = AppTheme.light(useGoogleFonts: false);

      // Verify onPrimary on primary for both themes
      final darkRatio = _contrastRatio(
        darkTheme.colorScheme.onPrimary,
        darkTheme.colorScheme.primary,
      );
      final lightRatio = _contrastRatio(
        lightTheme.colorScheme.onPrimary,
        lightTheme.colorScheme.primary,
      );

      expect(darkRatio, greaterThanOrEqualTo(4.5),
          reason: 'Dark theme onPrimary on primary must meet WCAG AA (>= 4.5:1)');
      expect(lightRatio, greaterThanOrEqualTo(4.5),
          reason: 'Light theme onPrimary on primary must meet WCAG AA (>= 4.5:1)');

      // Verify button foreground is dark text
      expect(darkTheme.colorScheme.onPrimary, const Color(0xFF15171C));
      expect(lightTheme.colorScheme.onPrimary, const Color(0xFF15171C));
    });

    test('Dark mode surfaces and text meet WCAG AA contrast', () {
      final darkTheme = AppTheme.dark(useGoogleFonts: false);
      final scheme = darkTheme.colorScheme;

      // Primary text on surfaces
      final onSurfaceOnBg = _contrastRatio(scheme.onSurface, scheme.surface);
      final onSurfaceOnContainer =
          _contrastRatio(scheme.onSurface, scheme.surfaceContainer);
      final onSurfaceOnRaised =
          _contrastRatio(scheme.onSurface, scheme.surfaceContainerHigh);

      expect(onSurfaceOnBg, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on background must meet WCAG AAA (>= 7.0:1)');
      expect(onSurfaceOnContainer, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on surface container must meet WCAG AAA');
      expect(onSurfaceOnRaised, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on raised container must meet WCAG AAA');

      // Secondary text on surfaces
      final onVarOnBg = _contrastRatio(scheme.onSurfaceVariant, scheme.surface);
      final onVarOnContainer =
          _contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainer);
      final onVarOnRaised =
          _contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainerHigh);

      expect(onVarOnBg, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on background must meet WCAG AA (>= 4.5:1)');
      expect(onVarOnContainer, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on surface container must meet WCAG AA');
      expect(onVarOnRaised, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on raised container must meet WCAG AA');

      // Accent blue on dark background
      final accentOnBg = _contrastRatio(scheme.secondary, scheme.surface);
      expect(accentOnBg, greaterThanOrEqualTo(4.5),
          reason: 'Accent blue on dark surface must meet WCAG AA');
    });

    test('Light mode surfaces and text meet WCAG AA contrast', () {
      final lightTheme = AppTheme.light(useGoogleFonts: false);
      final scheme = lightTheme.colorScheme;

      // Primary text on surfaces
      final onSurfaceOnBg = _contrastRatio(scheme.onSurface, scheme.surface);
      final onSurfaceOnContainer =
          _contrastRatio(scheme.onSurface, scheme.surfaceContainer);
      final onSurfaceOnRaised =
          _contrastRatio(scheme.onSurface, scheme.surfaceContainerHigh);

      expect(onSurfaceOnBg, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on light background must meet WCAG AAA (>= 7.0:1)');
      expect(onSurfaceOnContainer, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on light surface must meet WCAG AAA');
      expect(onSurfaceOnRaised, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on light raised container must meet WCAG AAA');

      // Secondary text on surfaces
      final onVarOnBg = _contrastRatio(scheme.onSurfaceVariant, scheme.surface);
      final onVarOnContainer =
          _contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainer);
      final onVarOnRaised =
          _contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainerHigh);

      expect(onVarOnBg, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on light background must meet WCAG AA (>= 4.5:1)');
      expect(onVarOnContainer, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on light surface container must meet WCAG AA');
      expect(onVarOnRaised, greaterThanOrEqualTo(4.5),
          reason: 'Secondary text on light raised container must meet WCAG AA');
    });
  });
}
