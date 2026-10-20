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

/// Robust offline-first service for real-time hardware step counting,
/// movement detection, calorie estimation, and active time tracking on the device.
///
/// Uses the hardware sensor `TYPE_STEP_COUNTER` via [pedometer] plugin.
/// Operates 100% offline without requiring internet connectivity.
class StepTrackingService with WidgetsBindingObserver {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;
  Timer? _retryTimer;

  final _statsController = StreamController<DailyStats>.broadcast();
  Stream<DailyStats> get statsStream => _statsController.stream;

  final ValueNotifier<bool> hasPermission = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSensorActive = ValueNotifier<bool>(false);
  final ValueNotifier<String> pedestrianStatus = ValueNotifier<String>('Stationary');

  bool _isListening = false;
  bool _hasObserver = false;
  bool _isReconnecting = false;

  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int? _lastRawSensorSteps;
  int? get lastRawSensorSteps => _lastRawSensorSteps;

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
    final granted = await checkPermission();
    if (!granted) {
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

  /// Initializes the hardware pedometer stream safely.
  Future<void> _initPedometerStream() async {
    if (kIsWeb) return;
    if (_stepSubscription != null) return;

    try {
      final isGranted = await checkPermission();
      if (!isGranted) {
        debugPrint('StepTrackingService: Cannot listen to pedometer without permission');
        isSensorActive.value = false;
        _isListening = false;
        return;
      }

      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('StepTrackingService: Pedometer step count stream error: $error');
          _onPedometerError(error);
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
        },
        onError: (error) {
          debugPrint('StepTrackingService: Pedestrian status stream error: $error');
          _statusSubscription?.cancel();
          _statusSubscription = null;
        },
        cancelOnError: false,
      );

      _isListening = true;
      isSensorActive.value = true;
      debugPrint('StepTrackingService: Hardware pedometer stream active');
    } catch (e) {
      debugPrint('StepTrackingService: Failed to initialize Pedometer stream: $e');
      _isListening = false;
      isSensorActive.value = false;
    }
  }

  void _onPedometerError(dynamic error) {
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _isListening = false;
    isSensorActive.value = false;

    // Schedule gentle retry to reconnect if sensor was temporarily busy
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), () {
      if (!_isListening) {
        _initPedometerStream();
      }
    });
  }

  /// Reconnects the sensor stream when returning from background.
  /// On Android, background sensor listeners can be stalled or detached by OS
  /// battery optimization. Re-subscribing forces SensorManager to register afresh
  /// and immediately flush accumulated hardware step events.
  Future<void> _reconnectSensorStream() async {
    if (kIsWeb || _isReconnecting) return;
    _isReconnecting = true;
    try {
      await _stepSubscription?.cancel();
      _stepSubscription = null;
      await _statusSubscription?.cancel();
      _statusSubscription = null;
      _isListening = false;

      await _initPedometerStream();
    } catch (e) {
      debugPrint('StepTrackingService: Error reconnecting sensor stream: $e');
    } finally {
      _isReconnecting = false;
    }
  }

  /// Pauses the hardware sensor listener when needed.
  void _pausePedometerStream() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _isListening = false;
    isSensorActive.value = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('StepTrackingService: App resumed, reconnecting sensors and refreshing stats');
      checkPermission().then((granted) {
        if (granted) {
          _reconnectSensorStream();
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

  /// Pulls the latest step count from local cache, re-verifies sensor, and broadcasts updated stats.
  Future<DailyStats> refresh() async {
    // 1. Try health service as optional local sensor sync if supported
    await syncWithHealthService();

    // 2. Load latest verified steps from local offline cache
    await _loadTodayCache();

    // 3. Broadcast updated stats
    _emitCurrentStats(forceSync: true);
    return getTodayStats();
  }

  /// Explicit sync with Health Connect or Apple Health if available.
  Future<DailyStats> syncWithHealthService() async {
    try {
      if (HealthService.instance.isSupported) {
        final healthSteps = await HealthService.instance.getStepsToday();
        if (healthSteps != null && healthSteps > _todaySteps) {
          _todaySteps = healthSteps;
          final prefs = await SharedPreferences.getInstance();
          final todayKey = dayKey(DateTime.now());
          await prefs.setInt('today_steps_$todayKey', _todaySteps);
          _emitCurrentStats();
        }
      }
    } catch (e) {
      debugPrint('StepTrackingService: Optional health sync note: $e');
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

  /// Event listener from [Pedometer.stepCountStream].
  Future<void> _onStepCount(StepCount event) async {
    try {
      await processStepReading(event.steps, eventTime: event.timeStamp);
    } catch (e) {
      debugPrint('StepTrackingService: Error in _onStepCount: $e');
    }
  }

  /// Core hardware step calculation engine.
  ///
  /// Pure offline calculation:
  /// - Reads cumulative step values from the hardware sensor (`TYPE_STEP_COUNTER`).
  /// - Calculates steps using the delta between latest and previous readings.
  /// - Accurately counts steps accumulated while app was minimized, screen locked,
  ///   or app process was closed.
  /// - Handles phone restarts (counter resets to 0) without losing earlier steps.
  /// - Automatically rolls over at midnight and archives yesterday's total.
  /// - Filters out duplicate readings and corrupt glitches.
  /// - Persists all data locally so tracking survives restarts without internet.
  @visibleForTesting
  Future<int> processStepReading(
    int raw, {
    DateTime? eventTime,
    SharedPreferences? overridePrefs,
  }) async {
    if (raw < 0) return _todaySteps;
    final prefs = overridePrefs ?? await SharedPreferences.getInstance();
    final now = eventTime ?? DateTime.now();
    final todayKeyStr = dayKey(now);

    final storedDate = prefs.getString('global_last_hardware_date');
    final storedLastRaw = prefs.getInt('global_last_hardware_steps');
    int currentDaySteps = prefs.getInt('today_steps_$todayKeyStr') ?? _todaySteps;

    // Case 1: First hardware reading established on this device/install
    if (storedLastRaw == null) {
      _lastRawSensorSteps = raw;
      _todaySteps = currentDaySteps; // Preserve any steps recorded today
      await prefs.setInt('global_last_hardware_steps', raw);
      await prefs.setString('global_last_hardware_date', todayKeyStr);
      await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);
      debugPrint('StepTrackingService: Initial hardware baseline set at $raw steps (today: $_todaySteps)');
      isSensorActive.value = true;
      _emitCurrentStats();
      return _todaySteps;
    }

    // Case 2: Midnight rollover (Date changed)
    if (storedDate != null && storedDate != todayKeyStr) {
      debugPrint('StepTrackingService: Midnight rollover detected ($storedDate -> $todayKeyStr)');

      // Archive yesterday's stats in local storage for history & weekly charts
      try {
        final yesterdaySteps = prefs.getInt('today_steps_$storedDate') ?? _todaySteps;
        final yesterdayDate = DateTime.tryParse(storedDate) ??
            DateTime(now.year, now.month, now.day - 1);
        await LocalDailyStatsStorage.instance.save(
          DailyStats(
            date: yesterdayDate,
            steps: yesterdaySteps,
            calories: (yesterdaySteps * 0.04).round(),
            activeMinutes: (yesterdaySteps / 100).ceil(),
          ),
          markPendingSync: true,
        );
      } catch (e) {
        debugPrint('StepTrackingService: Error archiving yesterday stats: $e');
      }

      // Compute steps accumulated overnight since yesterday's last reading
      int overnightDelta = 0;
      if (raw >= storedLastRaw) {
        overnightDelta = raw - storedLastRaw;
      } else {
        // Device rebooted overnight
        overnightDelta = raw;
      }

      // Sanitize delta against impossible hardware jumps
      if (overnightDelta < 0 || overnightDelta > 100000) {
        overnightDelta = 0;
      }

      // New day starts fresh: any existing steps for today (e.g. manual log) + overnight delta
      final existingToday = prefs.getInt('today_steps_$todayKeyStr') ?? 0;
      currentDaySteps = existingToday + overnightDelta;
    } else {
      // Case 3: Same day accumulation
      int delta = 0;
      if (raw < storedLastRaw) {
        // Device was rebooted: hardware counter reset to 0
        debugPrint('StepTrackingService: Phone reboot detected ($raw < $storedLastRaw)');
        delta = raw;
      } else {
        delta = raw - storedLastRaw;
      }

      // Prevent duplicate event increments (delta == 0) and filter corrupt spikes
      if (delta > 0 && delta <= 100000) {
        currentDaySteps += delta;
      } else if (delta > 100000) {
        debugPrint('StepTrackingService: Anomalous delta $delta ignored (raw=$raw, last=$storedLastRaw)');
      }
    }

    _todaySteps = currentDaySteps;
    _lastRawSensorSteps = raw;
    isSensorActive.value = true;

    // Persist all tracking state locally (100% offline)
    await prefs.setInt('global_last_hardware_steps', raw);
    await prefs.setString('global_last_hardware_date', todayKeyStr);
    await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);

    debugPrint('StepTrackingService: Processed raw=$raw, todaySteps=$_todaySteps');
    _emitCurrentStats(currentTime: now);
    return _todaySteps;
  }

  DateTime? _lastNotificationUpdateTime;
  int _lastNotifiedSteps = -1;

  void _emitCurrentStats({bool forceSync = false, DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final stats = DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    );
    // Broadcast live stats to all UI subscribers immediately
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

  @visibleForTesting
  void handlePedometerError(dynamic error) => _onPedometerError(error);

  @visibleForTesting
  void resetForTesting() {
    _todaySteps = 0;
    _lastRawSensorSteps = null;
    _lastNotificationUpdateTime = null;
    _lastNotifiedSteps = -1;
    isSensorActive.value = false;
    hasPermission.value = false;
    pedestrianStatus.value = 'Stationary';
    _isListening = false;
    _isReconnecting = false;
  }
}
