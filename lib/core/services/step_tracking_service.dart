import 'dart:async';
import 'dart:math' as math;

import 'package:fitbuddy/core/services/health_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/data/local_daily_stats_storage.dart';
import 'package:fitbuddy/features/dashboard/data/supabase_daily_stats_repository.dart';
import 'package:fitbuddy/features/workouts/data/supabase_workout_log_repository.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Robust universal offline-first service for real-time hardware step counting,
/// movement detection, calorie estimation, and active time tracking on the device.
///
/// Engineered for cross-OEM reliability across Samsung, Xiaomi/Redmi, OnePlus,
/// Google Pixel, Oppo, Vivo, Motorola, and all standard Android & iOS devices.
///
/// Core Capabilities:
/// 1. Primary: Hardware sensor `TYPE_STEP_COUNTER` via native EventChannel or [pedometer].
/// 2. Fallback: Hardware `TYPE_STEP_DETECTOR` when cumulative counter is unsupported.
/// 3. Strictly serialized asynchronous FIFO queue preventing concurrent write race conditions.
/// 4. Accurate midnight rollover and device reboot detection via SystemClock uptime.
/// 5. Non-destructive first-reading baseline establishment with same-day boot recovery.
/// 6. Decoupled Health Connect architecture: hardware tracking operates 100% offline
///    without external network calls or cache overwrites.
class StepTrackingService with WidgetsBindingObserver {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  static const MethodChannel _nativeChannel =
      MethodChannel('io.vyayama.fitbuddy/step_sensor');
  static const EventChannel _nativeEventChannel =
      EventChannel('io.vyayama.fitbuddy/step_events');

  StreamSubscription<dynamic>? _nativeEventSubscription;
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
  bool _isNativeStreamActive = false;

  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int? _lastRawSensorSteps;
  int? get lastRawSensorSteps => _lastRawSensorSteps;

  DateTime? _lastProcessedEventTime;
  DateTime? get lastProcessedEventTime => _lastProcessedEventTime;

  int get todayCalories => (_todaySteps * 0.04).round();
  int get todayActiveMinutes => (_todaySteps / 100).ceil();

  /// Serialized asynchronous FIFO queue ensuring each hardware event finishes completely
  /// before the next event updates baseline, totals, or persistent storage.
  Future<void> _eventQueue = Future.value();

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

    // 3. Check physical activity recognition permission without abruptly prompting on startup
    final granted = await checkPermission();
    if (granted) {
      await _initHardwareSensorStreams();
    } else {
      hasPermission.value = false;
      debugPrint('StepTrackingService: Physical activity permission not granted yet. Operating in fallback mode.');
    }

    // 4. Reconcile any native readings recorded while Flutter was starting
    await _reconcileNativeHardwareReading();

    // 5. Broadcast current stats
    _emitCurrentStats();
  }

  /// Checks if physical activity recognition permission is currently granted.
  Future<bool> checkPermission() async {
    if (kIsWeb) return false;
    try {
      final status = await Permission.activityRecognition.status;
      var granted = status.isGranted;
      if (!granted && defaultTargetPlatform == TargetPlatform.android) {
        final nativeGranted = await _nativeChannel
            .invokeMethod<bool>('hasActivityRecognitionPermission')
            .catchError((_) => null);
        if (nativeGranted == true) granted = true;
      }
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
        await _initHardwareSensorStreams();
        await refresh();
      }
      return granted;
    } catch (e) {
      debugPrint('StepTrackingService: Error requesting permission: $e');
      return false;
    }
  }

  /// Initializes hardware step sensor listeners across Native Android and Pedometer plugin.
  Future<void> _initHardwareSensorStreams() async {
    if (kIsWeb) return;
    if (_isListening) return;

    final isGranted = await checkPermission();
    if (!isGranted) {
      debugPrint('StepTrackingService: Cannot listen to hardware sensors without permission');
      isSensorActive.value = false;
      _isListening = false;
      return;
    }

    // 1. Try Native Android EventChannel first (direct SensorManager listener with batching)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        _nativeEventSubscription = _nativeEventChannel
            .receiveBroadcastStream()
            .listen(
          (dynamic event) {
            _onNativeSensorEvent(event);
          },
          onError: (error) {
            debugPrint('StepTrackingService: Native event channel error: $error');
            _isNativeStreamActive = false;
            _fallbackToPedometerPlugin();
          },
          cancelOnError: false,
        );

        _isNativeStreamActive = true;
        _isListening = true;
        isSensorActive.value = true;
        debugPrint('StepTrackingService: Native Android SensorManager stream active');
      } catch (e) {
        debugPrint('StepTrackingService: Native stream attach exception: $e');
        _fallbackToPedometerPlugin();
      }
    } else {
      _fallbackToPedometerPlugin();
    }

    // 2. Initialize PedestrianStatus stream for movement detection
    try {
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
          debugPrint('StepTrackingService: Pedestrian status error: $error');
          _statusSubscription?.cancel();
          _statusSubscription = null;
        },
        cancelOnError: false,
      );
    } catch (_) {}
  }

  /// Fallback to pedometer plugin on non-Android platforms or if native stream fails.
  void _fallbackToPedometerPlugin() {
    if (_stepSubscription != null) return;
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (!_isNativeStreamActive) {
            _queueStepCount(event.steps, eventTime: event.timeStamp);
          }
        },
        onError: (error) {
          debugPrint('StepTrackingService: Pedometer plugin stream error: $error');
          _onPedometerError(error);
        },
        cancelOnError: false,
      );
      _isListening = true;
      isSensorActive.value = true;
      debugPrint('StepTrackingService: Pedometer plugin stream active');
    } catch (e) {
      debugPrint('StepTrackingService: Failed to fallback to pedometer plugin: $e');
      _isListening = false;
      isSensorActive.value = false;
    }
  }

  void _onNativeSensorEvent(dynamic event) {
    if (event is! Map) return;
    try {
      final map = Map<String, dynamic>.from(event);
      final type = map['type'] as String? ?? 'counter';
      final steps = (map['steps'] as num?)?.toInt();
      final tsMs = (map['timestampMs'] as num?)?.toInt();
      final eventTime = tsMs != null && tsMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(tsMs)
          : DateTime.now();

      if (type == 'counter' && steps != null) {
        _queueStepCount(steps, eventTime: eventTime);
      } else if (type == 'detector') {
        _queueDetectorPulse(eventTime: eventTime);
      }
    } catch (e) {
      debugPrint('StepTrackingService: Error parsing native sensor event: $e');
    }
  }

  void _onPedometerError(dynamic error) {
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _isListening = false;
    isSensorActive.value = false;

    // Retry after 5s if sensor was temporarily unready
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), () {
      if (!_isListening) {
        _initHardwareSensorStreams();
      }
    });
  }

  /// Serialized event dispatch ensuring sequential FIFO order.
  Future<int> _queueStepCount(int raw, {DateTime? eventTime}) {
    final completer = Completer<int>();
    _eventQueue = _eventQueue.then((_) async {
      try {
        final result = await processStepReading(raw, eventTime: eventTime);
        completer.complete(result);
      } catch (e, stack) {
        debugPrint('StepTrackingService: Queue processing error: $e\n$stack');
        completer.complete(_todaySteps);
      }
    });
    return completer.future;
  }

  /// Serialized detector pulse dispatch.
  Future<int> _queueDetectorPulse({DateTime? eventTime}) {
    final completer = Completer<int>();
    _eventQueue = _eventQueue.then((_) async {
      try {
        final result = await processDetectorPulse(eventTime: eventTime);
        completer.complete(result);
      } catch (e) {
        completer.complete(_todaySteps);
      }
    });
    return completer.future;
  }

  /// Reconnects native & pedometer streams when returning from background.
  Future<void> _reconnectSensorStream() async {
    if (kIsWeb || _isReconnecting) return;
    _isReconnecting = true;
    try {
      await _nativeEventSubscription?.cancel();
      _nativeEventSubscription = null;
      await _stepSubscription?.cancel();
      _stepSubscription = null;
      await _statusSubscription?.cancel();
      _statusSubscription = null;
      _isListening = false;
      _isNativeStreamActive = false;

      await _initHardwareSensorStreams();
      await flushNativeSensor();
      await _reconcileNativeHardwareReading();
    } catch (e) {
      debugPrint('StepTrackingService: Error reconnecting sensor stream: $e');
    } finally {
      _isReconnecting = false;
    }
  }

  void _pausePedometerStream() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _isListening = false;
    _isNativeStreamActive = false;
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

  /// Flushes native Android hardware sensor queue if supported.
  Future<bool> flushNativeSensor() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final res = await _nativeChannel.invokeMethod<bool>('flushSensor');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Queries the device boot timestamp in milliseconds since epoch.
  Future<int?> getDeviceBootTimeMs() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final res = await _nativeChannel.invokeMethod<int>('getDeviceBootTimeMs');
      return res;
    } catch (_) {
      return null;
    }
  }

  /// Queries the latest raw reading persisted by native Android.
  Future<Map<String, dynamic>?> getLatestHardwareReading() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final res = await _nativeChannel.invokeMapMethod<String, dynamic>('getLatestHardwareReading');
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<void> _reconcileNativeHardwareReading() async {
    final reading = await getLatestHardwareReading();
    if (reading == null) return;
    final raw = (reading['rawSteps'] as num?)?.toInt();
    final tsMs = (reading['timestampMs'] as num?)?.toInt();
    final sensorType = reading['sensorType'] as String?;

    if (raw != null && raw > 0 && tsMs != null && tsMs > 0 && sensorType == 'counter') {
      final eventTime = DateTime.fromMillisecondsSinceEpoch(tsMs);
      await _queueStepCount(raw, eventTime: eventTime);
    }
  }

  /// Obtains rich diagnostic info from hardware sensor and battery managers.
  Future<Map<String, dynamic>> getSensorDiagnostics() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {
        'platform': defaultTargetPlatform.name,
        'isWeb': kIsWeb,
        'todaySteps': _todaySteps,
        'isSensorActive': isSensorActive.value,
      };
    }
    try {
      final res = await _nativeChannel.invokeMapMethod<String, dynamic>('getSensorDiagnostics');
      final diag = res != null ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      diag['todaySteps'] = _todaySteps;
      diag['isSensorActive'] = isSensorActive.value;
      diag['lastRawSensorSteps'] = _lastRawSensorSteps;
      diag['lastProcessedEventTime'] = _lastProcessedEventTime?.toIso8601String();
      return diag;
    } catch (e) {
      return {
        'error': e.toString(),
        'todaySteps': _todaySteps,
        'isSensorActive': isSensorActive.value,
      };
    }
  }

  /// Pulls the latest step count from local cache, flushes hardware sensor, and broadcasts updated stats.
  ///
  /// Decoupled: Health Connect is only used as a fallback if hardware sensors are absent.
  Future<DailyStats> refresh({DateTime? currentTime}) async {
    final now = currentTime ?? DateTime.now();

    // 1. Flush sensor if on Android
    await flushNativeSensor();

    // 2. Load latest verified steps from local offline cache
    await _loadTodayCache(nowOverride: now);

    // 3. Fallback only: if device completely lacks hardware sensor, check Health Connect
    if (!isSensorActive.value && HealthService.instance.isSupported) {
      await syncWithHealthService(currentTime: now);
    }

    // 4. Broadcast updated stats
    _emitCurrentStats(forceSync: true, currentTime: now);

    // 5. Sync offline pending records to cloud
    unawaited(syncPendingStatsToCloud());

    return getTodayStats(currentTime: now);
  }

  /// Explicit sync with Health Connect or Apple Health as an external source.
  Future<DailyStats> syncWithHealthService({DateTime? currentTime}) async {
    try {
      if (HealthService.instance.isSupported) {
        final healthSteps = await HealthService.instance.getStepsToday();
        if (healthSteps != null && healthSteps > _todaySteps) {
          _todaySteps = healthSteps;
          final prefs = await SharedPreferences.getInstance();
          final todayKeyStr = dayKey(currentTime ?? DateTime.now());
          await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);
          _emitCurrentStats(currentTime: currentTime);
        }
      }
    } catch (e) {
      debugPrint('StepTrackingService: Optional health sync note: $e');
    }
    return getTodayStats(currentTime: currentTime);
  }

  Future<void> _loadTodayCache({DateTime? nowOverride}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = nowOverride ?? DateTime.now();
      final todayKeyStr = dayKey(now);
      var cachedSteps = prefs.getInt('today_steps_$todayKeyStr');

      if (cachedSteps == null || cachedSteps == 0) {
        final local = await LocalDailyStatsStorage.instance.get(now);
        if (local != null && local.steps > 0) {
          cachedSteps = local.steps;
          await prefs.setInt('today_steps_$todayKeyStr', cachedSteps);
        }
      }

      final loaded = cachedSteps ?? 0;
      if (loaded > _todaySteps || _todaySteps == 0) {
        _todaySteps = loaded;
      }
      _emitCurrentStats(currentTime: now);
    } catch (_) {}
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
    int? overrideBootTimeMs,
  }) async {
    if (raw < 0) return _todaySteps;
    final prefs = overridePrefs ?? await SharedPreferences.getInstance();
    final now = eventTime ?? DateTime.now();
    final todayKeyStr = dayKey(now);

    // Filter out-of-order events
    if (eventTime != null && _lastProcessedEventTime != null) {
      if (eventTime.isBefore(_lastProcessedEventTime!)) {
        debugPrint(
            'StepTrackingService: Discarded out-of-order reading ($eventTime before $_lastProcessedEventTime)');
        return _todaySteps;
      }
    }

    final storedDate = prefs.getString('global_last_hardware_date');
    final storedLastRaw = prefs.getInt('global_last_hardware_steps');
    int currentDaySteps = prefs.getInt('today_steps_$todayKeyStr') ?? _todaySteps;

    // Fast-path: duplicate event on the same day with same raw reading
    if (storedDate == todayKeyStr && storedLastRaw != null && storedLastRaw == raw) {
      _lastProcessedEventTime = now;
      return _todaySteps;
    }

    // Case 1: First hardware reading established on this device/install
    if (storedLastRaw == null) {
      _lastRawSensorSteps = raw;
      _lastProcessedEventTime = now;

      // Check if device booted today
      final bootTimeMs = overrideBootTimeMs ?? await getDeviceBootTimeMs();
      final todayStart = DateTime(now.year, now.month, now.day);
      if (bootTimeMs != null && bootTimeMs >= todayStart.millisecondsSinceEpoch) {
        // Device booted today, so the hardware step counter started from 0 today.
        // Therefore, ALL raw steps since boot occurred today!
        currentDaySteps = math.max(currentDaySteps, raw);
      }

      _todaySteps = currentDaySteps;
      isSensorActive.value = true;
      await prefs.setInt('global_last_hardware_steps', raw);
      await prefs.setString('global_last_hardware_date', todayKeyStr);
      await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);
      debugPrint(
          'StepTrackingService: Initial hardware baseline set at $raw steps (today: $_todaySteps)');
      _emitCurrentStats(currentTime: now);
      return _todaySteps;
    }

    // Case 2: Midnight rollover (Date changed)
    if (storedDate != null && storedDate != todayKeyStr) {
      debugPrint(
          'StepTrackingService: Midnight rollover detected ($storedDate -> $todayKeyStr)');

      // Archive yesterday's stats in local storage for history & weekly charts
      try {
        final yesterdaySteps =
            prefs.getInt('today_steps_$storedDate') ?? _todaySteps;
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
      if (overnightDelta < 0 || overnightDelta > 50000) {
        debugPrint(
            'StepTrackingService: Anomalous overnight delta $overnightDelta ignored (raw=$raw, last=$storedLastRaw)');
        return _todaySteps;
      }

      // New day starts fresh with overnight delta
      final existingToday = prefs.getInt('today_steps_$todayKeyStr') ?? 0;
      currentDaySteps = existingToday + overnightDelta;
    } else {
      // Case 3: Same day accumulation
      int delta = 0;
      if (raw < storedLastRaw) {
        // Guard against minor transient sensor jitter
        if ((storedLastRaw - raw) < 100 && raw > 1000) {
          debugPrint(
              'StepTrackingService: Ignored minor sensor jitter ($raw < last $storedLastRaw)');
          return _todaySteps;
        }
        // Device was rebooted: hardware counter reset to 0
        debugPrint(
            'StepTrackingService: Phone reboot detected ($raw < $storedLastRaw)');
        delta = raw;
      } else {
        delta = raw - storedLastRaw;
      }

      // Prevent duplicate event increments (delta == 0) and filter corrupt spikes
      if (delta > 0 && delta <= 20000) {
        currentDaySteps += delta;
      } else if (delta > 20000) {
        debugPrint(
            'StepTrackingService: Anomalous delta $delta ignored (raw=$raw, last=$storedLastRaw)');
        return _todaySteps;
      }
    }

    _todaySteps = currentDaySteps;
    _lastRawSensorSteps = raw;
    _lastProcessedEventTime = now;
    isSensorActive.value = true;

    // Persist all tracking state locally (100% offline)
    await prefs.setInt('global_last_hardware_steps', raw);
    await prefs.setString('global_last_hardware_date', todayKeyStr);
    await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);

    final stats = DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    );
    await LocalDailyStatsStorage.instance.save(stats);

    debugPrint('StepTrackingService: Processed raw=$raw, todaySteps=$_todaySteps');
    _emitCurrentStats(currentTime: now);
    return _todaySteps;
  }

  /// Increments today steps by 1 for hardware that only supports `TYPE_STEP_DETECTOR`.
  @visibleForTesting
  Future<int> processDetectorPulse({
    DateTime? eventTime,
    SharedPreferences? overridePrefs,
  }) async {
    final prefs = overridePrefs ?? await SharedPreferences.getInstance();
    final now = eventTime ?? DateTime.now();
    final todayKeyStr = dayKey(now);

    final storedDate = prefs.getString('global_last_hardware_date');
    if (storedDate != null && storedDate != todayKeyStr) {
      // Midnight rollover
      final yesterdaySteps = prefs.getInt('today_steps_$storedDate') ?? _todaySteps;
      final yesterdayDate = DateTime.tryParse(storedDate) ?? DateTime(now.year, now.month, now.day - 1);
      await LocalDailyStatsStorage.instance.save(
        DailyStats(
          date: yesterdayDate,
          steps: yesterdaySteps,
          calories: (yesterdaySteps * 0.04).round(),
          activeMinutes: (yesterdaySteps / 100).ceil(),
        ),
        markPendingSync: true,
      );
      _todaySteps = 1;
    } else {
      _todaySteps += 1;
    }

    _lastProcessedEventTime = now;
    isSensorActive.value = true;
    await prefs.setString('global_last_hardware_date', todayKeyStr);
    await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);
    final stats = DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    );
    await LocalDailyStatsStorage.instance.save(stats);
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

      // Keep persistent lockscreen notification updated so live steps show at all times
      unawaited(NotificationService.instance.updateStepTrackingNotification(
        steps: _todaySteps,
        target: 10000,
        calories: todayCalories,
        activeMinutes: todayActiveMinutes,
      ));
    }
  }

  /// Manually increments step count (e.g. treadmill workout or testing).
  Future<void> addManualSteps(int count) async {
    if (count <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKeyStr = dayKey(now);
    _todaySteps += count;
    await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);
    await LocalDailyStatsStorage.instance.save(DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    ));
    _emitCurrentStats(forceSync: true);
  }

  /// Manually sets step count to a specific value.
  Future<void> setManualSteps(int count) async {
    if (count < 0) return;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKeyStr = dayKey(now);
    _todaySteps = count;
    await prefs.setInt('today_steps_$todayKeyStr', _todaySteps);
    await LocalDailyStatsStorage.instance.save(DailyStats(
      date: now,
      steps: _todaySteps,
      calories: todayCalories,
      activeMinutes: todayActiveMinutes,
    ));
    _emitCurrentStats(forceSync: true);
  }

  /// Resets today's step count back to 0 so the user can test physical walking from zero.
  Future<void> resetTodaySteps({DateTime? currentTime, SharedPreferences? overridePrefs}) async {
    final prefs = overridePrefs ?? await SharedPreferences.getInstance();
    final now = currentTime ?? DateTime.now();
    final todayKeyStr = dayKey(now);
    _todaySteps = 0;
    await prefs.setInt('today_steps_$todayKeyStr', 0);
    if (_lastRawSensorSteps != null) {
      await prefs.setInt('global_last_hardware_steps', _lastRawSensorSteps!);
      await prefs.setString('global_last_hardware_date', todayKeyStr);
    }
    await LocalDailyStatsStorage.instance.save(DailyStats(
      date: now,
      steps: 0,
      calories: 0,
      activeMinutes: 0,
    ));
    _emitCurrentStats(forceSync: true, currentTime: now);
  }

  /// Uploads any locally queued daily stats to Supabase when network is active.
  Future<void> syncPendingStatsToCloud() async {
    try {
      final repo = SupabaseDailyStatsRepository();
      final pendingDates =
          await LocalDailyStatsStorage.instance.getPendingSyncDates();
      if (pendingDates.isEmpty) return;

      for (final dateStr in pendingDates) {
        try {
          final date = parseDayKey(dateStr);
          final stats = await LocalDailyStatsStorage.instance.get(date);
          if (stats != null) {
            await repo.upsert(stats);
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final workoutLogRepo = SupabaseWorkoutLogRepository();
      await workoutLogRepo.syncPendingLogs();
    } catch (_) {}
  }

  /// Returns current today stats synchronously if already loaded.
  DailyStats getTodayStats({DateTime? currentTime}) {
    return DailyStats(
      date: currentTime ?? DateTime.now(),
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
  Future<int> queueStepCountForTesting(int raw, {DateTime? eventTime}) =>
      _queueStepCount(raw, eventTime: eventTime);

  @visibleForTesting
  Future<int> queueDetectorPulseForTesting({DateTime? eventTime}) =>
      _queueDetectorPulse(eventTime: eventTime);

  @visibleForTesting
  void resetForTesting() {
    _todaySteps = 0;
    _lastRawSensorSteps = null;
    _lastProcessedEventTime = null;
    _lastNotificationUpdateTime = null;
    _lastNotifiedSteps = -1;
    isSensorActive.value = false;
    hasPermission.value = false;
    pedestrianStatus.value = 'Stationary';
    _isListening = false;
    _isReconnecting = false;
    _isNativeStreamActive = false;
    _eventQueue = Future.value();
  }
}
