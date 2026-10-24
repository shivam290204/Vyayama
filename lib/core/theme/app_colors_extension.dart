import 'package:flutter/material.dart';

/// Semantic colors theme extension providing brand tokens for features
/// like streaks, hydration, achievements, and warnings across light/dark themes.
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.streak,
    required this.streakContainer,
    required this.onStreak,
    required this.water,
    required this.waterContainer,
    required this.onWater,
    required this.success,
    required this.successContainer,
    required this.onSuccess,
    required this.warning,
    required this.warningContainer,
    required this.onWarning,
    required this.danger,
    required this.dangerContainer,
    required this.onDanger,
    required this.amberWarning,
    required this.amberWarningContainer,
    required this.onAmberWarning,
    required this.workoutWarmup,
    required this.workoutIntermediate,
    required this.workoutAdvanced,
    required this.workoutCooldown,
    required this.pill,
    required this.sleep,
    required this.cardBorder,
    required this.stageBackground,
    required this.stageBorder,
    required this.alarmFlame,
    required this.sun,
    required this.diagnosticHealthy,
    required this.diagnosticHealthyBorder,
  });

  final Color streak;
  final Color streakContainer;
  final Color onStreak;
  final Color water;
  final Color waterContainer;
  final Color onWater;
  final Color success;
  final Color successContainer;
  final Color onSuccess;
  final Color warning;
  final Color warningContainer;
  final Color onWarning;
  final Color danger;
  final Color dangerContainer;
  final Color onDanger;
  final Color amberWarning;
  final Color amberWarningContainer;
  final Color onAmberWarning;
  final Color workoutWarmup;
  final Color workoutIntermediate;
  final Color workoutAdvanced;
  final Color workoutCooldown;
  final Color pill;
  final Color sleep;
  final Color cardBorder;
  final Color stageBackground;
  final Color stageBorder;
  final Color alarmFlame;
  final Color sun;
  final Color diagnosticHealthy;
  final Color diagnosticHealthyBorder;

  static const light = AppColorsExtension(
    streak: Color(0xFFFF6B2C),
    streakContainer: Color(0xFFFFE5D6),
    onStreak: Color(0xFF15171C),
    water: Color(0xFF3DA9FC),
    waterContainer: Color(0xFFE2F1FD),
    onWater: Color(0xFF15171C),
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFE8F5E9),
    onSuccess: Colors.white,
    warning: Color(0xFFB83E08),
    warningContainer: Color(0xFFFFE5D6),
    onWarning: Color(0xFF15171C),
    danger: Color(0xFFD32F2F),
    dangerContainer: Color(0xFFFFEBEE),
    onDanger: Colors.white,
    amberWarning: Color(0xFFD97706),
    amberWarningContainer: Color(0xFFFFF8E1),
    onAmberWarning: Color(0xFF15171C),
    workoutWarmup: Color(0xFF3DA9FC),
    workoutIntermediate: Color(0xFFFF9800),
    workoutAdvanced: Color(0xFFFF6B2C),
    workoutCooldown: Color(0xFF3DA9FC),
    pill: Color(0xFF3DA9FC),
    sleep: Color(0xFF3DA9FC),
    cardBorder: Color(0xFFDDD8D0),
    stageBackground: Color(0xFFF0EEEA),
    stageBorder: Color(0xFFDDD8D0),
    alarmFlame: Color(0xFFFF6B2C),
    sun: Color(0xFFFF6B2C),
    diagnosticHealthy: Color(0xFFE8F5E9),
    diagnosticHealthyBorder: Color(0xFF4CAF50),
  );

  static const dark = AppColorsExtension(
    streak: Color(0xFFFF6B2C),
    streakContainer: Color(0xFF331B10),
    onStreak: Color(0xFF15171C),
    water: Color(0xFF3DA9FC),
    waterContainer: Color(0xFF1B2836),
    onWater: Color(0xFF15171C),
    success: Color(0xFF4CAF50),
    successContainer: Color(0xFF1B2D22),
    onSuccess: Color(0xFF15171C),
    warning: Color(0xFFFF8A50),
    warningContainer: Color(0xFF331B10),
    onWarning: Color(0xFF15171C),
    danger: Color(0xFFE53935),
    dangerContainer: Color(0xFF331414),
    onDanger: Colors.white,
    amberWarning: Color(0xFFF59E0B),
    amberWarningContainer: Color(0xFF332810),
    onAmberWarning: Color(0xFF15171C),
    workoutWarmup: Color(0xFF3DA9FC),
    workoutIntermediate: Color(0xFFFF9800),
    workoutAdvanced: Color(0xFFFF6B2C),
    workoutCooldown: Color(0xFF3DA9FC),
    pill: Color(0xFF3DA9FC),
    sleep: Color(0xFF3DA9FC),
    cardBorder: Color(0xFF363C4A),
    stageBackground: Color(0xFF1A1D24),
    stageBorder: Color(0xFF232730),
    alarmFlame: Color(0xFFFF6B2C),
    sun: Color(0xFFFF6B2C),
    diagnosticHealthy: Color(0xFF1B2D22),
    diagnosticHealthyBorder: Color(0xFF4CAF50),
  );

  @override
  AppColorsExtension copyWith({
    Color? streak,
    Color? streakContainer,
    Color? onStreak,
    Color? water,
    Color? waterContainer,
    Color? onWater,
    Color? success,
    Color? successContainer,
    Color? onSuccess,
    Color? warning,
    Color? warningContainer,
    Color? onWarning,
    Color? danger,
    Color? dangerContainer,
    Color? onDanger,
    Color? amberWarning,
    Color? amberWarningContainer,
    Color? onAmberWarning,
    Color? workoutWarmup,
    Color? workoutIntermediate,
    Color? workoutAdvanced,
    Color? workoutCooldown,
    Color? pill,
    Color? sleep,
    Color? cardBorder,
    Color? stageBackground,
    Color? stageBorder,
    Color? alarmFlame,
    Color? sun,
    Color? diagnosticHealthy,
    Color? diagnosticHealthyBorder,
  }) {
    return AppColorsExtension(
      streak: streak ?? this.streak,
      streakContainer: streakContainer ?? this.streakContainer,
      onStreak: onStreak ?? this.onStreak,
      water: water ?? this.water,
      waterContainer: waterContainer ?? this.waterContainer,
      onWater: onWater ?? this.onWater,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDanger: onDanger ?? this.onDanger,
      amberWarning: amberWarning ?? this.amberWarning,
      amberWarningContainer: amberWarningContainer ?? this.amberWarningContainer,
      onAmberWarning: onAmberWarning ?? this.onAmberWarning,
      workoutWarmup: workoutWarmup ?? this.workoutWarmup,
      workoutIntermediate: workoutIntermediate ?? this.workoutIntermediate,
      workoutAdvanced: workoutAdvanced ?? this.workoutAdvanced,
      workoutCooldown: workoutCooldown ?? this.workoutCooldown,
      pill: pill ?? this.pill,
      sleep: sleep ?? this.sleep,
      cardBorder: cardBorder ?? this.cardBorder,
      stageBackground: stageBackground ?? this.stageBackground,
      stageBorder: stageBorder ?? this.stageBorder,
      alarmFlame: alarmFlame ?? this.alarmFlame,
      sun: sun ?? this.sun,
      diagnosticHealthy: diagnosticHealthy ?? this.diagnosticHealthy,
      diagnosticHealthyBorder: diagnosticHealthyBorder ?? this.diagnosticHealthyBorder,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      streak: Color.lerp(streak, other.streak, t) ?? streak,
      streakContainer: Color.lerp(streakContainer, other.streakContainer, t) ?? streakContainer,
      onStreak: Color.lerp(onStreak, other.onStreak, t) ?? onStreak,
      water: Color.lerp(water, other.water, t) ?? water,
      waterContainer: Color.lerp(waterContainer, other.waterContainer, t) ?? waterContainer,
      onWater: Color.lerp(onWater, other.onWater, t) ?? onWater,
      success: Color.lerp(success, other.success, t) ?? success,
      successContainer: Color.lerp(successContainer, other.successContainer, t) ?? successContainer,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t) ?? warningContainer,
      onWarning: Color.lerp(onWarning, other.onWarning, t) ?? onWarning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t) ?? dangerContainer,
      onDanger: Color.lerp(onDanger, other.onDanger, t) ?? onDanger,
      amberWarning: Color.lerp(amberWarning, other.amberWarning, t) ?? amberWarning,
      amberWarningContainer: Color.lerp(amberWarningContainer, other.amberWarningContainer, t) ?? amberWarningContainer,
      onAmberWarning: Color.lerp(onAmberWarning, other.onAmberWarning, t) ?? onAmberWarning,
      workoutWarmup: Color.lerp(workoutWarmup, other.workoutWarmup, t) ?? workoutWarmup,
      workoutIntermediate: Color.lerp(workoutIntermediate, other.workoutIntermediate, t) ?? workoutIntermediate,
      workoutAdvanced: Color.lerp(workoutAdvanced, other.workoutAdvanced, t) ?? workoutAdvanced,
      workoutCooldown: Color.lerp(workoutCooldown, other.workoutCooldown, t) ?? workoutCooldown,
      pill: Color.lerp(pill, other.pill, t) ?? pill,
      sleep: Color.lerp(sleep, other.sleep, t) ?? sleep,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t) ?? cardBorder,
      stageBackground: Color.lerp(stageBackground, other.stageBackground, t) ?? stageBackground,
      stageBorder: Color.lerp(stageBorder, other.stageBorder, t) ?? stageBorder,
      alarmFlame: Color.lerp(alarmFlame, other.alarmFlame, t) ?? alarmFlame,
      sun: Color.lerp(sun, other.sun, t) ?? sun,
      diagnosticHealthy: Color.lerp(diagnosticHealthy, other.diagnosticHealthy, t) ?? diagnosticHealthy,
      diagnosticHealthyBorder: Color.lerp(diagnosticHealthyBorder, other.diagnosticHealthyBorder, t) ?? diagnosticHealthyBorder,
    );
  }
}

/// Convenience extension on [BuildContext] to access semantic app colors.
extension AppColorsThemeExtension on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>() ?? AppColorsExtension.light;
}
