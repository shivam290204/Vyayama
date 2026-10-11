import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Service for integrating Apple HealthKit and Android Health Connect via [health] package.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _isConfigured = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Whether the current platform supports HealthKit or Health Connect.
  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
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
