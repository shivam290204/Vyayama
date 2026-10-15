import 'dart:async';
import 'dart:math' as math;

import 'package:fitbuddy/core/services/health_service.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Robust service for real-time hardware step counting, calorie estimation,
/// and active time tracking on the device.
class StepTrackingService with WidgetsBindingObserver {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  final _statsController = StreamController<DailyStats>.broadcast();
  Stream<DailyStats> get statsStream => _statsController.stream;

  bool _isListening = false;
  bool _hasObserver = false;
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int get todayCalories => (_todaySteps * 0.04).round();
  int get todayActiveMinutes => (_todaySteps / 100).ceil();

  /// Starts listening to device hardware step sensors if permissions are granted.
  Future<void> start() async {
    // 1. Load cached steps for today first so UI shows latest immediately
    await _loadTodayCache();

    // 2. Register lifecycle observer once to auto-refresh and reconnect on app resume
    if (!_hasObserver) {
      WidgetsBinding.instance.addObserver(this);
      _hasObserver = true;
    }

    if (kIsWeb) return;

    // 3. Safely check and request ACTIVITY_RECOGNITION permission
    try {
      final status = await Permission.activityRecognition.status;
      if (!status.isGranted) {
        final requested = await Permission.activityRecognition.request();
        if (!requested.isGranted) {
          debugPrint('StepTrackingService: ACTIVITY_RECOGNITION permission not granted: $requested');
          return;
        }
      }
    } catch (e) {
      debugPrint('StepTrackingService: Error requesting activity recognition: $e');
      return;
    }

    // 4. Connect hardware pedometer stream
    await _initPedometerStream();

    // 5. Complement steps from Health Connect / Apple Health if available
    unawaited(refresh());
  }

  Future<void> _initPedometerStream() async {
    if (kIsWeb) return;
    if (_stepSubscription != null) return;

    try {
      final isGranted = await Permission.activityRecognition.isGranted;
      if (!isGranted) return;

      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('Pedometer step count stream error: $error');
          _stepSubscription?.cancel();
          _stepSubscription = null;
          _isListening = false;
        },
        cancelOnError: false,
      );

      _statusSubscription ??= Pedometer.pedestrianStatusStream.listen(
        (status) {
          debugPrint('Pedestrian status: ${status.status}');
        },
        onError: (error) {
          debugPrint('Pedometer status stream error: $error');
          _statusSubscription?.cancel();
          _statusSubscription = null;
        },
        cancelOnError: false,
      );

      _isListening = true;
    } catch (e) {
      debugPrint('Failed to initialize Pedometer stream: $e');
      _isListening = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('StepTrackingService: App resumed, re-checking step stream and refreshing stats');
      if (!_isListening) {
        _initPedometerStream();
      }
      refresh();
    }
  }

  /// Pulls the latest step count from SharedPreferences cache
  /// and Health Connect / Apple Health, then broadcasts updated stats.
  Future<DailyStats> refresh() async {
    await _loadTodayCache();

    // Complement with OS Health Connect / Apple Health if available
    try {
      final healthSteps = await HealthService.instance.getStepsToday();
      if (healthSteps != null && healthSteps > _todaySteps) {
        _todaySteps = healthSteps;
        final prefs = await SharedPreferences.getInstance();
        final todayKey = dayKey(DateTime.now());
        await prefs.setInt('today_steps_$todayKey', _todaySteps);
      }
    } catch (e) {
      debugPrint('Failed to get health steps: $e');
    }

    _emitCurrentStats();
    return getTodayStats();
  }

  Future<void> _loadTodayCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = dayKey(DateTime.now());
      final cached = prefs.getInt('today_steps_$todayKey') ?? 0;
      if (cached > _todaySteps) {
        _todaySteps = cached;
      }
      _emitCurrentStats();
    } catch (_) {}
  }

  Future<void> _onStepCount(StepCount event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = dayKey(now);
      final baseKey = 'steps_base_$todayKey';
      final offsetKey = 'steps_offset_$todayKey';

      var baseSteps = prefs.getInt(baseKey);
      var offset = prefs.getInt(offsetKey) ?? 0;

      if (baseSteps == null || baseSteps <= 0) {
        // First reading of the day
        baseSteps = event.steps;
        await prefs.setInt(baseKey, baseSteps);
      } else if (event.steps < baseSteps) {
        // Device rebooted: preserve previously accumulated steps in offset
        offset = _todaySteps;
        baseSteps = event.steps;
        await prefs.setInt(offsetKey, offset);
        await prefs.setInt(baseKey, baseSteps);
      }

      final computed = offset + (event.steps - baseSteps);
      final newSteps = math.max(_todaySteps, computed);

      if (newSteps > _todaySteps) {
        _todaySteps = newSteps;
        await prefs.setInt('today_steps_$todayKey', _todaySteps);
        _emitCurrentStats();
      }
    } catch (e) {
      debugPrint('Error updating step count: $e');
    }
  }

  void _emitCurrentStats() {
    final now = DateTime.now();
    final stats = DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    );
    _statsController.add(stats);
  }

  /// Returns current today stats synchronously if already loaded.
  DailyStats getTodayStats() {
    return DailyStats(
      date: DateTime.now(),
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    );
  }

  /// Stops tracking subscriptions and cleans up observers.
  Future<void> stop() async {
    if (_hasObserver) {
      WidgetsBinding.instance.removeObserver(this);
      _hasObserver = false;
    }
    await _stepSubscription?.cancel();
    await _statusSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription = null;
    _isListening = false;
  }
}
