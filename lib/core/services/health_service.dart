import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/services/step_tracking_service.dart';

/// Service for integrating Apple HealthKit and Android Health Connect via [health] package.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  static const String kHealthSyncEnabledKey = 'vyayama_health_sync_enabled';

  final Health _health = Health();
  bool _isConfigured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  @visibleForTesting
  bool? isSupportedOverride;

  @visibleForTesting
  String? serviceNameOverride;

  @visibleForTesting
  Future<int?> Function()? stepsTodayOverride;

  @visibleForTesting
  Future<int?> Function()? activeCaloriesTodayOverride;

  /// Whether the current platform supports HealthKit or Health Connect.
  bool get isSupported {
    if (isSupportedOverride != null) return isSupportedOverride!;
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Platform-specific display name for the connected health system.
  String get serviceName {
    if (serviceNameOverride != null) return serviceNameOverride!;
    if (kIsWeb) return 'Health Services';
    if (Platform.isIOS) return 'Apple Health';
    if (Platform.isAndroid) return 'Google Health Connect';
    return 'Health Services';
  }

  @visibleForTesting
  void resetForTesting() {
    isSupportedOverride = null;
    serviceNameOverride = null;
    stepsTodayOverride = null;
    activeCaloriesTodayOverride = null;
  }

  /// Checks whether health sync has been enabled by the user in settings.
  Future<bool> isSyncEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(kHealthSyncEnabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether permissions have been granted by HealthKit or Health Connect.
  Future<bool> hasPermissions() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    try {
      final hasPerm = await _health.hasPermissions(_types);
      return hasPerm ?? false;
    } catch (_) {
      return isSyncEnabled();
    }
  }

  /// Requests authorization from HealthKit or Health Connect, enables sync,
  /// and performs an initial step sync.
  Future<bool> connect() async {
    if (!isSupported) return false;
    final granted = await requestPermissions();
    if (granted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(kHealthSyncEnabledKey, true);
      } catch (_) {}
      try {
        await StepTrackingService.instance.syncWithHealthService();
      } catch (_) {}
    }
    return granted;
  }

  /// Disables external health synchronization in user preferences.
  Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHealthSyncEnabledKey, false);
    } catch (_) {}
  }

  Future<void> _ensureConfigured() async {
    if (_isConfigured || !isSupported) return;
    try {
      await _health.configure();
      _isConfigured = true;
    } catch (e) {
      debugPrint('Health configuration error: $e');
    }
  }

  /// Requests permission to read steps and active energy from the health provider.
  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    await _ensureConfigured();

    try {
      final granted = await _health.requestAuthorization(_types);
      return granted;
    } catch (e) {
      debugPrint('Health authorization request failed: $e');
      return false;
    }
  }

  /// Returns total steps walked today, or null if health data is unavailable.
  Future<int?> getStepsToday() async {
    if (stepsTodayOverride != null) return stepsTodayOverride!();
    if (!isSupported) return null;
    await _ensureConfigured();

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps;
    } catch (e) {
      debugPrint('Failed to fetch steps: $e');
      return null;
    }
  }

  /// Returns active energy burned today (kcal), or null if unavailable.
  Future<int?> getActiveCaloriesToday() async {
    if (activeCaloriesTodayOverride != null) {
      return activeCaloriesTodayOverride!();
    }
    if (!isSupported) return null;
    await _ensureConfigured();

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        startTime: midnight,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );

      var totalKcal = 0.0;
      for (final point in data) {
        final val = point.value;
        if (val is NumericHealthValue) {
          totalKcal += val.numericValue.toDouble();
        }
      }
      return totalKcal.round();
    } catch (e) {
      debugPrint('Failed to fetch active calories: $e');
      return null;
    }
  }
}
