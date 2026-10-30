/// Central feature flags and configuration for the Vyayama Intelligence Layer.
abstract final class IntelligenceConfig {
  /// Master feature flag for intelligence features.
  ///
  /// Can be toggled at compile-time via:
  /// `--dart-define=ENABLE_INTELLIGENCE=false`
  static const bool isEnabled = bool.fromEnvironment(
    'ENABLE_INTELLIGENCE',
    defaultValue: true,
  );

  /// Maximum number of insights to present concurrently on the dashboard.
  static const int maxVisibleInsights = 3;

  /// Days of trailing statistics evaluated by the insights engine.
  static const int analysisWindowDays = 14;

  /// Threshold percentage change in steps considered significant enough to surface.
  static const double stepChangeThreshold = 0.15; // 15%
}
