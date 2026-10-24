import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fitbuddy/core/theme/app_colors_extension.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';

export 'package:fitbuddy/core/theme/app_colors_extension.dart';

/// Centralized Vyayama brand palette.
/// Modern high-energy Orange & Sky Blue design system with accessible contrast.
/// Palette specifications:
/// - Dark: background #0F1115, surface #1A1D24, raised #232730, primary #FF6B2C, accent #3DA9FC, text #F4F5F7, secondary text #A9AFBC.
/// - Light: background #FAF8F5, text #15171C, same primary and accent.
/// - Only 3 main colours (primary #FF6B2C, accent #3DA9FC, mascot/healthy green #4CAF50) plus neutrals.
/// - Dark text on orange buttons (#15171C on #FF6B2C -> 6.31:1 WCAG AA).
/// - No red on missed-item cards.
abstract final class AppPalette {
  // Brand Main Colours
  static const Color primaryOrange = Color(0xFFFF6B2C); // Primary brand & action: #FF6B2C
  static const Color accentBlue = Color(0xFF3DA9FC);    // Accent, hydration & secondary highlights: #3DA9FC
  static const Color mascotGreen = Color(0xFF4CAF50);   // Success status & mascot harmony: #4CAF50

  // Dark mode surfaces & neutrals
  static const Color darkBackground = Color(0xFF0F1115); // Dark mode background: #0F1115
  static const Color darkSurface = Color(0xFF1A1D24);    // Cards & surfaces: #1A1D24
  static const Color darkRaised = Color(0xFF232730);     // Raised / surfaceContainerHigh: #232730
  static const Color darkSurfaceContainer = darkSurface;
  static const Color darkSurfaceContainerHigh = darkRaised;
  static const Color darkSurfaceContainerHighest = Color(0xFF2C313D);
  static const Color darkOutline = Color(0xFF363C4A);
  static const Color darkText = Color(0xFFF4F5F7);       // Primary text: #F4F5F7
  static const Color darkTextMuted = Color(0xFFA9AFBC);  // Secondary text: #A9AFBC

  // Light mode surfaces & neutrals
  static const Color lightBackground = Color(0xFFFAF8F5); // Main background: #FAF8F5
  static const Color lightSurface = Color(0xFFFFFFFF);   // Cards & surfaces: #FFFFFF
  static const Color lightRaised = Color(0xFFF0EEEA);    // Raised / containers: #F0EEEA
  static const Color lightSurfaceContainer = lightSurface;
  static const Color lightSurfaceContainerHigh = lightRaised;
  static const Color lightSurfaceContainerHighest = Color(0xFFE6E2DB);
  static const Color lightOutline = Color(0xFFDDD8D0);
  static const Color lightText = Color(0xFF15171C);      // Main text: #15171C
  static const Color lightTextMuted = Color(0xFF5C6370); // Secondary text (WCAG AA > 5.5:1)

  // Accessible text variants of primary/accent on light backgrounds (WCAG AA >= 4.5:1)
  static const Color lightPrimaryAccessible = Color(0xFFB83E08);
  static const Color lightAccentAccessible = Color(0xFF0D72B8);

  // PIP & specialized surfaces
  static const Color pipBackground = darkBackground;
  static const Color pipBadgeBackground = primaryOrange;
  static const Color pipBadgeText = lightText;

  // Semantic & backward-compatible aliases
  static const Color primary = primaryOrange;
  static const Color secondary = accentBlue;
  static const Color tertiary = accentBlue;
  static const Color accent = accentBlue;
  static const Color highlight = accentBlue;
  static const Color forestGreen = primaryOrange;
  static const Color deepGreen = primaryOrange;
  static const Color limeGreen = accentBlue;
  static const Color softLime = Color(0xFFD8ECFD);
  static const Color charcoalGreen = darkSurface;
  static const Color offWhite = darkText;
  static const Color softCoral = Color(0xFFFF8A50);
  static const Color deepCoral = Color(0xFFE08272);
  static const Color error = Color(0xFFBA1A1A);
}

/// Material 3 light and dark themes built using the modern palette.
abstract final class AppTheme {
  static ThemeData light({bool useGoogleFonts = true}) =>
      _build(Brightness.light, useGoogleFonts: useGoogleFonts);
  static ThemeData dark({bool useGoogleFonts = true}) =>
      _build(Brightness.dark, useGoogleFonts: useGoogleFonts);

  static ThemeData _build(Brightness brightness, {bool useGoogleFonts = true}) {
    final isDark = brightness == Brightness.dark;

    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: AppPalette.primaryOrange,
            onPrimary: AppPalette.lightText, // Dark text on orange buttons (#15171C on #FF6B2C)
            primaryContainer: Color(0xFF331B10),
            onPrimaryContainer: AppPalette.primaryOrange,
            secondary: AppPalette.accentBlue,
            onSecondary: AppPalette.lightText,
            secondaryContainer: Color(0xFF1B2836),
            onSecondaryContainer: Color(0xFFA4D4FD),
            tertiary: AppPalette.accentBlue,
            onTertiary: AppPalette.lightText,
            tertiaryContainer: Color(0xFF1B2836),
            onTertiaryContainer: Color(0xFFA4D4FD),
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000A),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: AppPalette.darkBackground,
            onSurface: AppPalette.darkText,
            onSurfaceVariant: AppPalette.darkTextMuted,
            surfaceContainerLowest: Color(0xFF0A0C0E),
            surfaceContainerLow: Color(0xFF14161C),
            surfaceContainer: AppPalette.darkSurface,
            surfaceContainerHigh: AppPalette.darkRaised,
            surfaceContainerHighest: Color(0xFF2C313D),
            outline: AppPalette.darkOutline,
            outlineVariant: Color(0xFF262B35),
            shadow: Colors.black,
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: AppPalette.primaryOrange,
            onPrimary: AppPalette.lightText, // Dark text on orange buttons (#15171C on #FF6B2C)
            primaryContainer: Color(0xFFFFE5D6),
            onPrimaryContainer: Color(0xFF8A2E05),
            secondary: AppPalette.accentBlue,
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFFE2F1FD),
            onSecondaryContainer: Color(0xFF095288),
            tertiary: AppPalette.accentBlue,
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFE2F1FD),
            onTertiaryContainer: Color(0xFF095288),
            error: AppPalette.error,
            onError: Colors.white,
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: AppPalette.lightBackground,
            onSurface: AppPalette.lightText,
            onSurfaceVariant: AppPalette.lightTextMuted,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Color(0xFFFDFCFA),
            surfaceContainer: AppPalette.lightSurface,
            surfaceContainerHigh: AppPalette.lightRaised,
            surfaceContainerHighest: Color(0xFFE6E2DB),
            outline: AppPalette.lightOutline,
            outlineVariant: Color(0xFFEAE6DF),
            shadow: Color(0x26FF6B2C),
          );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = (useGoogleFonts
            ? GoogleFonts.nunitoTextTheme(base.textTheme)
            : base.textTheme)
        .apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final roundedLg = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(
        color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
        width: 1,
      ),
    );
    final buttonText = textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
    );

    return base.copyWith(
      extensions: [isDark ? AppColorsExtension.dark : AppColorsExtension.light],
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primaryOrange,
          foregroundColor: AppPalette.lightText, // Dark text on orange buttons
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          elevation: isDark ? 2 : 1,
          textStyle: buttonText?.copyWith(color: AppPalette.lightText),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primaryOrange,
          foregroundColor: AppPalette.lightText, // Dark text on orange buttons
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          elevation: isDark ? 2 : 1,
          textStyle: buttonText?.copyWith(color: AppPalette.lightText),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? AppPalette.primaryOrange : AppPalette.lightPrimaryAccessible,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: isDark
                ? AppPalette.primaryOrange.withValues(alpha: 0.75)
                : AppPalette.primaryOrange,
            width: 1.5,
          ),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? AppPalette.primaryOrange : AppPalette.lightPrimaryAccessible,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppPalette.primaryOrange,
        foregroundColor: AppPalette.lightText, // Dark text on orange FAB
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.primaryOrange,
        linearTrackColor:
            isDark ? const Color(0xFF282C36) : const Color(0xFFFFE5D6),
        circularTrackColor:
            isDark ? const Color(0xFF282C36) : const Color(0xFFFFE5D6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? AppPalette.darkSurface : AppPalette.lightRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppPalette.primaryOrange,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 0.5,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
        margin: EdgeInsets.zero,
        color: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isDark
                ? AppPalette.darkOutline.withValues(alpha: 0.5)
                : AppPalette.lightOutline,
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        modalBackgroundColor: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(
          color: isDark ? AppPalette.darkOutline : AppPalette.lightOutline,
          width: 1,
        ),
        backgroundColor:
            isDark ? AppPalette.darkRaised : AppPalette.lightRaised,
        selectedColor:
            isDark ? const Color(0xFF331B10) : const Color(0xFFFFE5D6),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: isDark ? AppPalette.darkText : AppPalette.lightText,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppPalette.accentBlue : AppPalette.primaryOrange,
          size: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor:
            isDark ? AppPalette.darkSurface : AppPalette.lightBackground,
        indicatorColor:
            isDark ? const Color(0xFF331B10) : const Color(0xFFFFE5D6),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppPalette.primaryOrange);
          }
          return IconThemeData(color: textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected
                ? (isDark ? AppPalette.primaryOrange : AppPalette.lightPrimaryAccessible)
                : textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: AppPalette.primaryOrange,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: isDark ? AppPalette.primaryOrange : AppPalette.lightPrimaryAccessible,
        unselectedLabelColor: textMuted,
        labelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.lightText;
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.primaryOrange;
          }
          return isDark ? const Color(0xFF282C36) : const Color(0xFFE2DDD5);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppPalette.primaryOrange;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppPalette.lightText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? const Color(0xFF331B10) : const Color(0xFFFFE5D6);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? AppPalette.primaryOrange : AppPalette.lightPrimaryAccessible;
            }
            return textMuted;
          }),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? AppPalette.darkRaised : AppPalette.darkSurface,
        contentTextStyle: const TextStyle(color: AppPalette.darkText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: roundedLg,
        backgroundColor: isDark ? AppPalette.darkSurface : AppPalette.lightSurface,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
