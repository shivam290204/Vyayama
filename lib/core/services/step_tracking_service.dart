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

  final ValueNotifier<bool> hasPermission = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSensorActive = ValueNotifier<bool>(false);

  bool _isListening = false;
  bool _hasObserver = false;
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int get todayCalories => (_todaySteps * 0.04).round();
  int get todayActiveMinutes => (_todaySteps / 100).ceil();

  /// Starts listening to device hardware step sensors and refreshes cached stats.
  Future<void> start() async {
    // 1. Load cached steps for today first so UI shows latest immediately
    await _loadTodayCache();

    // 2. Register lifecycle observer once to auto-refresh and reconnect on app resume
    if (!_hasObserver) {
      WidgetsBinding.instance.addObserver(this);
      _hasObserver = true;
    }

    if (kIsWeb) return;

    // 3. Check and request ACTIVITY_RECOGNITION permission
    await checkPermission();
    if (!hasPermission.value) {
      await requestPermission();
    } else {
      await _initPedometerStream();
    }

    // 4. Complement steps from Health Connect / Apple Health if available
    unawaited(refresh());
  }

  /// Checks if physical activity recognition permission is currently granted.
  Future<bool> checkPermission() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.activityRecognition.status;
      final granted = status.isGranted;
      hasPermission.value = granted;
      return granted;
    } catch (e) {
      debugPrint('StepTrackingService: Error checking permission: $e');
      return false;
    }
  }

  /// Explicitly prompts the user for activity recognition permission or opens settings.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isPermanentlyDenied) {
        debugPrint('StepTrackingService: Permission permanently denied, opening settings');
        await openAppSettings();
        return false;
      }

      final requested = await Permission.activityRecognition.request();
      final granted = requested.isGranted;
      hasPermission.value = granted;

      if (granted) {
        await _initPedometerStream();
        await refresh();
      }
      return granted;
    } catch (e) {
      debugPrint('StepTrackingService: Error requesting permission: $e');
      return false;
    }
  }

  Future<void> _initPedometerStream() async {
    if (kIsWeb) return;
    if (_stepSubscription != null) return;

    try {
      final isGranted = await checkPermission();
      if (!isGranted) {
        debugPrint('StepTrackingService: Cannot listen to pedometer without permission');
        return;
      }

      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('Pedometer step count stream error: $error');
          _stepSubscription?.cancel();
          _stepSubscription = null;
          _isListening = false;
          isSensorActive.value = false;
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
      isSensorActive.value = true;
      debugPrint('StepTrackingService: Hardware pedometer stream active');
    } catch (e) {
      debugPrint('Failed to initialize Pedometer stream: $e');
      _isListening = false;
      isSensorActive.value = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('StepTrackingService: App resumed, re-evaluating sensors and stats');
      checkPermission().then((granted) {
        if (granted && !_isListening) {
          _initPedometerStream();
        }
      });
      refresh();
    }
  }

  /// Manually increments step count (e.g. treadmill workout or testing).
  Future<void> addManualSteps(int count) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = dayKey(DateTime.now());
    _todaySteps += count;
    await prefs.setInt('today_steps_$todayKey', _todaySteps);
    _emitCurrentStats();
  }

  /// Manually sets step count to a specific value.
  Future<void> setManualSteps(int count) async {
    if (count < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = dayKey(DateTime.now());
    _todaySteps = count;
    await prefs.setInt('today_steps_$todayKey', _todaySteps);
    _emitCurrentStats();
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

      if (baseSteps == null) {
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
    isSensorActive.value = false;
  }
}
