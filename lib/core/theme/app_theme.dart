import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Centralized Vyayama brand palette.
/// Forest Green & Lime Green design system with accessible contrast.
abstract final class AppPalette {
  // Brand Colours
  static const Color forestGreen = Color(0xFF14532D); // Primary buttons & brand
  static const Color deepGreen = Color(0xFF2E7D32);   // Secondary actions & accents
  static const Color limeGreen = Color(0xFF8BCF45);   // Progress, active states & highlights
  static const Color softLime = Color(0xFFDDF2B5);    // Soft highlight & chip containers
  static const Color offWhite = Color(0xFFF7F8F2);    // Light mode background
  static const Color charcoalGreen = Color(0xFF202820); // Dark mode surface & deep text
  static const Color softCoral = Color(0xFFFFB49F);   // Warning / rest alerts & accents

  // Dark mode surfaces
  static const Color darkBackground = Color(0xFF151D17); // Dark mode background: #151D17
  static const Color darkSurface = charcoalGreen;        // Cards: #202820
  static const Color darkSurfaceContainer = Color(0xFF253025);
  static const Color darkSurfaceContainerHigh = Color(0xFF2C392C);
  static const Color darkSurfaceContainerHighest = Color(0xFF334333);
  static const Color darkOutline = Color(0xFF3B4D3B);
  static const Color darkText = offWhite;                // Primary text: #F7F8F2
  static const Color darkTextMuted = Color(0xFFA6B7A6);

  // Light mode surfaces
  static const Color lightBackground = offWhite;         // Main background: #F7F8F2
  static const Color lightSurface = Color(0xFFFFFFFF);   // Cards: #FFFFFF
  static const Color lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHigh = Color(0xFFFAFAF7);
  static const Color lightSurfaceContainerHighest = Color(0xFFEEF3EA);
  static const Color lightOutline = Color(0xFFE5E9E0);
  static const Color lightText = Color(0xFF202820);      // Main text: #202820
  static const Color lightTextMuted = Color(0xFF667366); // Secondary text: #667366

  // Backward-compatible semantic aliases
  static const Color primary = forestGreen;
  static const Color secondary = deepGreen;
  static const Color tertiary = limeGreen;
  static const Color accent = limeGreen;
  static const Color highlight = limeGreen;
  static const Color error = Color(0xFFBA1A1A);
}

/// Material 3 light and dark themes built using the Forest Green & Lime Green system.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    final scheme = isDark
        ? const ColorScheme(
            brightness: Brightness.dark,
            primary: AppPalette.forestGreen,
            onPrimary: Colors.white,
            primaryContainer: Color(0xFF1A3320),
            onPrimaryContainer: AppPalette.limeGreen,
            secondary: AppPalette.deepGreen,
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFF243624),
            onSecondaryContainer: AppPalette.softLime,
            tertiary: AppPalette.limeGreen,
            onTertiary: AppPalette.charcoalGreen,
            tertiaryContainer: Color(0xFF2E4028),
            onTertiaryContainer: AppPalette.softLime,
            error: Color(0xFFFFB4AB),
            onError: Color(0xFF690005),
            errorContainer: Color(0xFF93000A),
            onErrorContainer: Color(0xFFFFDAD6),
            surface: AppPalette.darkBackground,
            onSurface: AppPalette.darkText,
            onSurfaceVariant: AppPalette.darkTextMuted,
            surfaceContainerLowest: Color(0xFF111711),
            surfaceContainerLow: Color(0xFF192219),
            surfaceContainer: AppPalette.darkSurface,
            surfaceContainerHigh: AppPalette.darkSurfaceContainerHigh,
            surfaceContainerHighest: AppPalette.darkSurfaceContainerHighest,
            outline: AppPalette.darkOutline,
            outlineVariant: Color(0xFF2C3B2C),
            shadow: Colors.black,
          )
        : const ColorScheme(
            brightness: Brightness.light,
            primary: AppPalette.forestGreen,
            onPrimary: Colors.white,
            primaryContainer: AppPalette.softLime,
            onPrimaryContainer: AppPalette.forestGreen,
            secondary: AppPalette.deepGreen,
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFFE8F3DF),
            onSecondaryContainer: AppPalette.forestGreen,
            tertiary: AppPalette.limeGreen,
            onTertiary: AppPalette.charcoalGreen,
            tertiaryContainer: AppPalette.softLime,
            onTertiaryContainer: AppPalette.forestGreen,
            error: AppPalette.error,
            onError: Colors.white,
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: AppPalette.lightBackground,
            onSurface: AppPalette.lightText,
            onSurfaceVariant: AppPalette.lightTextMuted,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Color(0xFFF9FAF5),
            surfaceContainer: Colors.white,
            surfaceContainerHigh: Color(0xFFFAFAF7),
            surfaceContainerHighest: Color(0xFFEEF3EA),
            outline: AppPalette.lightOutline,
            outlineVariant: Color(0xFFE5E9E0),
            shadow: Color(0xFF14532D),
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
          backgroundColor:
              isDark ? AppPalette.deepGreen : AppPalette.forestGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          elevation: isDark ? 2 : 1,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: isDark
                ? AppPalette.limeGreen.withValues(alpha: 0.6)
                : AppPalette.forestGreen,
            width: 1.5,
          ),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppPalette.limeGreen,
        foregroundColor: AppPalette.charcoalGreen,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppPalette.limeGreen,
        linearTrackColor:
            isDark ? const Color(0xFF283628) : AppPalette.softLime,
        circularTrackColor:
            isDark ? const Color(0xFF283628) : AppPalette.softLime,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark ? const Color(0xFF263226) : AppPalette.lightSurfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
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
        shadowColor: AppPalette.forestGreen.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        color: isDark ? AppPalette.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isDark
                ? AppPalette.darkOutline.withValues(alpha: 0.5)
                : const Color(0xFFE5E9E0),
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF1E281E) : Colors.white,
        modalBackgroundColor: isDark ? const Color(0xFF1E281E) : Colors.white,
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
            isDark ? const Color(0xFF253225) : AppPalette.lightSurfaceContainer,
        selectedColor:
            isDark ? AppPalette.forestGreen : AppPalette.softLime,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: isDark ? AppPalette.darkText : AppPalette.lightText,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
          size: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor:
            isDark ? AppPalette.darkSurface : AppPalette.lightBackground,
        indicatorColor:
            isDark ? const Color(0xFF2E3E28) : AppPalette.softLime,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
                color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen);
          }
          return IconThemeData(color: textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected
                ? (isDark ? AppPalette.limeGreen : AppPalette.forestGreen)
                : textMuted,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
        unselectedLabelColor: textMuted,
        labelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? AppPalette.limeGreen : AppPalette.forestGreen;
          }
          return isDark ? const Color(0xFF2E3D2E) : const Color(0xFFDCE4DA);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? AppPalette.limeGreen : AppPalette.forestGreen;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(
            isDark ? AppPalette.charcoalGreen : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? const Color(0xFF2E3E28) : AppPalette.softLime;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark ? AppPalette.limeGreen : AppPalette.forestGreen;
            }
            return textMuted;
          }),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isDark ? const Color(0xFF2A362A) : AppPalette.charcoalGreen,
        contentTextStyle: const TextStyle(color: AppPalette.offWhite),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: roundedLg,
        backgroundColor: isDark ? AppPalette.darkSurface : Colors.white,
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
