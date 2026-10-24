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
  group('Vyayama Nature & Wellness Green Theme Contrast Compliance', () {
    test('White text on Forest Green primary buttons meets WCAG AAA (> 7.0:1)', () {
      final darkTheme = AppTheme.dark(useGoogleFonts: false);
      final lightTheme = AppTheme.light(useGoogleFonts: false);

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

      expect(darkTheme.colorScheme.onPrimary, Colors.white);
      expect(lightTheme.colorScheme.onPrimary, Colors.white);
      expect(lightTheme.colorScheme.primary, const Color(0xFF14532D)); // Forest Green
    });

    test('Dark mode surfaces and text meet WCAG contrast', () {
      final darkTheme = AppTheme.dark(useGoogleFonts: false);
      final scheme = darkTheme.colorScheme;

      // Primary text on surfaces
      final onSurfaceOnBg = _contrastRatio(scheme.onSurface, scheme.surface);
      final onSurfaceOnContainer =
          _contrastRatio(scheme.onSurface, scheme.surfaceContainer);

      expect(onSurfaceOnBg, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on background must meet WCAG AAA (>= 7.0:1)');
      expect(onSurfaceOnContainer, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on surface container must meet WCAG AAA');

      // Lime green accent on dark background
      final accentOnBg = _contrastRatio(AppPalette.limeGreen, scheme.surface);
      expect(accentOnBg, greaterThanOrEqualTo(4.5),
          reason: 'Lime Green accent on dark surface must meet WCAG AA');
    });

    test('Light mode surfaces and text meet WCAG contrast', () {
      final lightTheme = AppTheme.light(useGoogleFonts: false);
      final scheme = lightTheme.colorScheme;

      // Primary text on surfaces
      final onSurfaceOnBg = _contrastRatio(scheme.onSurface, scheme.surface);
      final onSurfaceOnContainer =
          _contrastRatio(scheme.onSurface, scheme.surfaceContainer);

      expect(onSurfaceOnBg, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on light background must meet WCAG AAA (>= 7.0:1)');
      expect(onSurfaceOnContainer, greaterThanOrEqualTo(7.0),
          reason: 'Primary text on light surface must meet WCAG AAA');

      // Forest green primary on light background
      final primaryOnBg = _contrastRatio(scheme.primary, scheme.surface);
      expect(primaryOnBg, greaterThanOrEqualTo(4.5),
          reason: 'Forest Green primary on light surface must meet WCAG AA');
    });

    test('Verified palette color constants match user brand specification', () {
      expect(AppPalette.forestGreen, const Color(0xFF14532D));
      expect(AppPalette.deepGreen, const Color(0xFF2E7D32));
      expect(AppPalette.limeGreen, const Color(0xFF8BCF45));
      expect(AppPalette.softLime, const Color(0xFFDDF2B5));
      expect(AppPalette.offWhite, const Color(0xFFF7F8F2));
      expect(AppPalette.charcoalGreen, const Color(0xFF202820));
      expect(AppPalette.darkBackground, const Color(0xFF151D17));
    });
  });
}
