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
    streak: Color(0xFFFF9500),
    streakContainer: Color(0xFFFFF3E0),
    onStreak: Colors.white,
    water: Color(0xFF00B4D8),
    waterContainer: Color(0xFFE8F1F5),
    onWater: Colors.white,
    success: Color(0xFF2E7D32),
    successContainer: Color(0xFFE8F5E9),
    onSuccess: Colors.white,
    warning: Color(0xFFC04B35),
    warningContainer: Color(0xFFFFB49F),
    onWarning: Color(0xFF5C1B10),
    danger: Color(0xFFFF0000),
    dangerContainer: Color(0xFFFFEBEE),
    onDanger: Colors.white,
    amberWarning: Color(0xFFE5A000),
    amberWarningContainer: Color(0xFFFFF8E1),
    onAmberWarning: Color(0xFF8A5A00),
    workoutWarmup: Color(0xFF0D9488),
    workoutIntermediate: Color(0xFFD97706),
    workoutAdvanced: Color(0xFFC2410C),
    workoutCooldown: Color(0xFF2563EB),
    pill: Color(0xFF673AB7),
    sleep: Color(0xFF818CF8),
    cardBorder: Color(0xFFE5E9E0),
    stageBackground: Color(0xFF192319),
    stageBorder: Color(0xFF14532D),
    alarmFlame: Color(0xFFE25822),
    sun: Color(0xFFFBBF24),
    diagnosticHealthy: Color(0xFFE8F5E9),
    diagnosticHealthyBorder: Color(0xFF81C784),
  );

  static const dark = AppColorsExtension(
    streak: Color(0xFFFF9500),
    streakContainer: Color(0xFF2C1E14),
    onStreak: Colors.white,
    water: Color(0xFF64B5F6),
    waterContainer: Color(0xFF263226),
    onWater: Colors.white,
    success: Color(0xFF8BCF45),
    successContainer: Color(0xFF1F2B1F),
    onSuccess: Color(0xFF202820),
    warning: Color(0xFFFFB49F),
    warningContainer: Color(0xFF332014),
    onWarning: Color(0xFFF7F8F2),
    danger: Color(0xFFFF0000),
    dangerContainer: Color(0xFF331414),
    onDanger: Colors.white,
    amberWarning: Color(0xFFE5A000),
    amberWarningContainer: Color(0xFF332810),
    onAmberWarning: Colors.white,
    workoutWarmup: Color(0xFF0D9488),
    workoutIntermediate: Color(0xFFD97706),
    workoutAdvanced: Color(0xFFC2410C),
    workoutCooldown: Color(0xFF2563EB),
    pill: Color(0xFF818CF8),
    sleep: Color(0xFF818CF8),
    cardBorder: Color(0xFF3B4D3B),
    stageBackground: Color(0xFF141A14),
    stageBorder: Color(0xFF2E3D2E),
    alarmFlame: Color(0xFFE25822),
    sun: Color(0xFFFBBF24),
    diagnosticHealthy: Color(0xFF142B14),
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
