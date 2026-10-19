import 'dart:async';

import 'package:fitbuddy/core/services/health_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Robust service for real-time hardware step counting, movement detection,
/// calorie estimation, and active time tracking on the device.
class StepTrackingService with WidgetsBindingObserver {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  final _statsController = StreamController<DailyStats>.broadcast();
  Stream<DailyStats> get statsStream => _statsController.stream;

  final ValueNotifier<bool> hasPermission = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSensorActive = ValueNotifier<bool>(false);
  final ValueNotifier<String> pedestrianStatus = ValueNotifier<String>('Stationary');

  bool _isListening = false;
  bool _hasObserver = false;
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int? _lastRawSensorSteps;

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

    // 4. Broadcast current stats
    _emitCurrentStats();
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

  /// Explicitly prompts the user for activity recognition permission.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isPermanentlyDenied) {
        debugPrint('StepTrackingService: Permission permanently denied');
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
          _pausePedometerStream();
        },
        cancelOnError: false,
      );

      _statusSubscription ??= Pedometer.pedestrianStatusStream.listen(
        (status) {
          final s = status.status.toLowerCase();
          if (s == 'walking') {
            pedestrianStatus.value = 'Walking';
          } else if (s == 'stopped') {
            pedestrianStatus.value = 'Stationary';
          } else {
            pedestrianStatus.value = status.status;
          }
          debugPrint('Pedestrian status: ${pedestrianStatus.value}');
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

  /// Pauses the hardware sensor listener when app goes to background.
  /// Prevents Android OS / vendor battery savers from forcefully killing the app process.
  void _pausePedometerStream() {
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _isListening = false;
    isSensorActive.value = false;
    debugPrint('StepTrackingService: Hardware pedometer stream paused to prevent OS battery kill');
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
    // We intentionally do not pause the pedometer stream when minimized or screen locked.
    // Keeping it active ensures walking with the phone in your pocket continues counting live!
  }

  /// Manually increments step count (e.g. treadmill workout or testing).
  Future<void> addManualSteps(int count) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = dayKey(DateTime.now());
    _todaySteps += count;
    await prefs.setInt('today_steps_$todayKey', _todaySteps);
    _emitCurrentStats(forceSync: true);
  }

  /// Manually sets step count to a specific value.
  Future<void> setManualSteps(int count) async {
    if (count < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final todayKey = dayKey(DateTime.now());
    _todaySteps = count;
    await prefs.setInt('today_steps_$todayKey', _todaySteps);
    _emitCurrentStats(forceSync: true);
  }

  /// Resets today's step count back to 0 so the user can test physical walking from zero.
  Future<void> resetTodaySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = dayKey(DateTime.now());
    _todaySteps = 0;
    await prefs.setInt('today_steps_$todayKey', 0);
    if (_lastRawSensorSteps != null) {
      await prefs.setInt('global_last_hardware_steps', _lastRawSensorSteps!);
      await prefs.setString('global_last_hardware_date', todayKey);
    }
    _emitCurrentStats(forceSync: true);
  }

  /// Pulls the latest step count from SharedPreferences cache, then broadcasts updated stats.
  Future<DailyStats> refresh() async {
    await _loadTodayCache();
    _emitCurrentStats(forceSync: true);
    return getTodayStats();
  }

  /// Explicit sync with Health Connect or Apple Health.
  Future<DailyStats> syncWithHealthService() async {
    try {
      final healthSteps = await HealthService.instance.getStepsToday();
      if (healthSteps != null && healthSteps > _todaySteps) {
        _todaySteps = healthSteps;
        final prefs = await SharedPreferences.getInstance();
        final todayKey = dayKey(DateTime.now());
        await prefs.setInt('today_steps_$todayKey', _todaySteps);
        _emitCurrentStats();
      }
    } catch (e) {
      debugPrint('Failed to get health steps: $e');
    }
    return getTodayStats();
  }

  Future<void> _loadTodayCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = dayKey(now);
      var cachedSteps = prefs.getInt('today_steps_$todayKey');

      if (cachedSteps == null || cachedSteps == 0) {
        final local = await LocalDailyStatsStorage.instance.get(now);
        if (local != null && local.steps > 0) {
          cachedSteps = local.steps;
          await prefs.setInt('today_steps_$todayKey', cachedSteps);
        }
      }

      _todaySteps = cachedSteps ?? 0;
      _emitCurrentStats();
    } catch (_) {}
  }

  /// Real-time hardware step processing:
  /// Accurately computes steps walked when app is open, minimized, or completely closed.
  Future<void> _onStepCount(StepCount event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = dayKey(now);

      final raw = event.steps;
      final storedLastRaw = prefs.getInt('global_last_hardware_steps');
      final storedLastDate = prefs.getString('global_last_hardware_date');

      if (storedLastRaw == null) {
        // First hardware reading established on this device
        await prefs.setInt('global_last_hardware_steps', raw);
        await prefs.setString('global_last_hardware_date', todayKey);
        await prefs.setInt('today_steps_$todayKey', _todaySteps);
        _lastRawSensorSteps = raw;
        debugPrint('StepTrackingService: Hardware sensor baseline set at $raw steps');
        _emitCurrentStats();
        return;
      }

      int delta = 0;
      if (raw < storedLastRaw) {
        // Device was rebooted while app was open or closed: counter reset to 0
        debugPrint('StepTrackingService: Phone reboot detected ($raw < $storedLastRaw)');
        delta = raw;
      } else {
        delta = raw - storedLastRaw;
      }

      if (storedLastDate != todayKey) {
        // Day rolled over (e.g. overnight while app was closed or running)
        debugPrint('StepTrackingService: New day detected ($storedLastDate -> $todayKey)');
        _todaySteps += (delta > 0 ? delta : 0);
      } else {
        // Same day: add steps taken (including any while app was closed!)
        if (delta > 0) {
          _todaySteps += delta;
        }
      }

      _lastRawSensorSteps = raw;
      await prefs.setInt('global_last_hardware_steps', raw);
      await prefs.setString('global_last_hardware_date', todayKey);
      await prefs.setInt('today_steps_$todayKey', _todaySteps);

      debugPrint('StepTrackingService: Processed +$delta steps (raw: $raw). Today total: $_todaySteps');
      _emitCurrentStats();
    } catch (e) {
      debugPrint('Error updating step count: $e');
    }
  }

  DateTime? _lastNotificationUpdateTime;
  int _lastNotifiedSteps = -1;

  void _emitCurrentStats({bool forceSync = false}) {
    final now = DateTime.now();
    final stats = DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    );
    // Always broadcast live stats to UI subscribers immediately
    _statsController.add(stats);

    final timeSinceLastNotif = _lastNotificationUpdateTime == null
        ? const Duration(seconds: 10)
        : now.difference(_lastNotificationUpdateTime!);

    if (forceSync ||
        timeSinceLastNotif.inSeconds >= 2 ||
        (_todaySteps - _lastNotifiedSteps).abs() >= 5) {
      _lastNotificationUpdateTime = now;
      _lastNotifiedSteps = _todaySteps;
      unawaited(LocalDailyStatsStorage.instance.save(stats));

      // Keep persistent lockscreen notification updated so live steps show at all times
      unawaited(NotificationService.instance.updateStepTrackingNotification(
        steps: _todaySteps,
        target: 10000,
        calories: todayCalories,
        activeMinutes: todayActiveMinutes,
      ));
    }
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
    _pausePedometerStream();
    pedestrianStatus.value = 'Stationary';
  }
}
