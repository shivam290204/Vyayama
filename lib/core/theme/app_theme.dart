import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

abstract final class AppPalette {
  // Dark mode
  static const Color darkBackground = Color(0xFF14141A);
  static const Color darkSurface = Color(0xFF21212B);
  static const Color darkText = Color(0xFFF2F2F7);

  // Light mode
  static const Color lightBackground = Color(0xFFF7F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF14141A);

  // Shared
  // Original primary #7B61FF failed WCAG AA (4.21:1) with white text.
  // Darkened to #7356FF to hit 4.65:1 contrast ratio.
  static const Color primary = Color(0xFF7356FF);
  static const Color accent = Color(0xFFC8F169);
  static const Color error = Color(0xFFFF5D5D);
}

/// Material 3 light and dark themes built using AppPalette.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    final background = isDark ? AppPalette.darkBackground : AppPalette.lightBackground;
    final surface = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final text = isDark ? AppPalette.darkText : AppPalette.lightText;
    
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      secondary: AppPalette.accent,
      onSecondary: AppPalette.darkBackground,
      error: AppPalette.error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      // Provide fallback values for required fields
      primaryContainer: AppPalette.primary.withValues(alpha: 0.15),
      onPrimaryContainer: AppPalette.primary,
      secondaryContainer: AppPalette.accent.withValues(alpha: isDark ? 0.15 : 1.0),
      onSecondaryContainer: isDark ? AppPalette.accent : AppPalette.darkText,
      surfaceContainerHighest: isDark ? const Color(0xFF2C2C35) : const Color(0xFFEBEBF0),
      outline: isDark ? const Color(0xFF3A3A4A) : const Color(0xFFD1D1D6),
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final roundedLg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    );
    final buttonText = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        shape: roundedLg,
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: background,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: roundedLg,
        backgroundColor: scheme.surface,
      ),
    );
  }
}
