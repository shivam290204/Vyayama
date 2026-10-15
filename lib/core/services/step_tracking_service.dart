import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fitbuddy/core/services/health_service.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for real-time hardware step counting, background foreground service,
/// calorie estimation, and active time tracking on the device.
class StepTrackingService with WidgetsBindingObserver {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  static const _channel = MethodChannel('io.vyayama.fitbuddy/step_service');

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

  /// Starts listening to device hardware step sensors and background service if available.
  Future<void> start() async {
    // 1. Load cached steps for today first
    await _loadTodayCache();

    // 2. Register lifecycle observer once to auto-refresh on app resume
    if (!_hasObserver) {
      WidgetsBinding.instance.addObserver(this);
      _hasObserver = true;
    }

    if (kIsWeb) return;

    // 3. Request permissions required for step counting and foreground notification
    try {
      final actStatus = await Permission.activityRecognition.request();
      if (!actStatus.isGranted) {
        debugPrint('Activity recognition permission: $actStatus');
      }
      if (Platform.isAndroid) {
        final notifStatus = await Permission.notification.request();
        if (!notifStatus.isGranted) {
          debugPrint('Notification permission for background tracking: $notifStatus');
        }
      }
    } catch (e) {
      debugPrint('Permission request error in StepTrackingService: $e');
    }

    // 4. Start native Android background Foreground Service
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startStepService');
        debugPrint('Started native Android StepForegroundService for background tracking');
      } catch (e) {
        debugPrint('Could not start native StepForegroundService: $e');
      }
    }

    // 5. Connect Flutter pedometer stream for instant in-app reactivity
    _initPedometerStream();

    // 6. Refresh steps from native service & Health Connect
    unawaited(refresh());
  }

  void _initPedometerStream() {
    if (_stepSubscription != null) return;

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('Pedometer step count stream error: $error');
          _stepSubscription?.cancel();
          _stepSubscription = null;
          _isListening = false;
          // Retry after delay in case sensor temporarily unavailable
          Future.delayed(const Duration(seconds: 10), () {
            if (!_isListening) _initPedometerStream();
          });
        },
        onDone: () {
          _stepSubscription?.cancel();
          _stepSubscription = null;
          _isListening = false;
        },
      );

      _statusSubscription ??= Pedometer.pedestrianStatusStream.listen(
        (status) {
          debugPrint('Pedestrian status: ${status.status}');
        },
        onError: (error) {
          debugPrint('Pedometer status stream error: $error');
        },
      );

      _isListening = true;
    } catch (e) {
      debugPrint('Failed to start Pedometer stream: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('StepTrackingService: App resumed, refreshing steps from background service and sensors');
      _initPedometerStream();
      refresh();
    }
  }

  /// Pulls the latest step count from native background service, SharedPreferences,
  /// and Health Connect, and broadcasts updated stats.
  Future<DailyStats> refresh() async {
    await _loadTodayCache();

    // 1. Check native background service steps via MethodChannel if Android
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final nativeSteps = await _channel.invokeMethod<int>('getTodaySteps');
        if (nativeSteps != null && nativeSteps > _todaySteps) {
          _todaySteps = nativeSteps;
          final prefs = await SharedPreferences.getInstance();
          final todayKey = dayKey(DateTime.now());
          await prefs.setInt('today_steps_$todayKey', _todaySteps);
        }
      } catch (e) {
        debugPrint('Failed to get native steps: $e');
      }
    }

    // 2. Complement with OS Health Connect / Apple Health if available
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

  /// Stops tracking subscriptions and native foreground service.
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

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopStepService');
      } catch (_) {}
    }
  }
}
