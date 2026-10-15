import 'dart:async';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for real-time hardware step counting, calorie estimation,
/// and active time tracking on the device.
class StepTrackingService {
  StepTrackingService._();
  static final StepTrackingService instance = StepTrackingService._();

  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  final _statsController = StreamController<DailyStats>.broadcast();
  Stream<DailyStats> get statsStream => _statsController.stream;

  bool _isListening = false;
  int _todaySteps = 0;
  int get todaySteps => _todaySteps;

  int get todayCalories => (_todaySteps * 0.04).round();
  int get todayActiveMinutes => (_todaySteps / 100).ceil();

  /// Starts listening to device hardware step sensors if available.
  Future<void> start() async {
    if (_isListening) return;

    // Load cached steps for today first
    await _loadTodayCache();

    if (kIsWeb) return;

    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        debugPrint('Activity recognition permission not granted: $status');
      }

      _stepSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('Pedometer step count stream error: $error');
        },
      );

      _statusSubscription = Pedometer.pedestrianStatusStream.listen(
        (status) {
          debugPrint('Pedestrian status: ${status.status}');
        },
        onError: (error) {
          debugPrint('Pedometer status stream error: $error');
        },
      );

      _isListening = true;
    } catch (e) {
      debugPrint('Failed to start Pedometer step tracking: $e');
    }
  }

  Future<void> _loadTodayCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = dayKey(DateTime.now());
      _todaySteps = prefs.getInt('today_steps_$todayKey') ?? 0;
      _emitCurrentStats();
    } catch (_) {}
  }

  Future<void> _onStepCount(StepCount event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayKey = dayKey(now);
      final baseKey = 'steps_base_$todayKey';

      var baseSteps = prefs.getInt(baseKey);
      if (baseSteps == null || baseSteps <= 0 || event.steps < baseSteps) {
        // First reading of the day or phone rebooted
        baseSteps = event.steps;
        await prefs.setInt(baseKey, baseSteps);
      }

      final computed = event.steps - baseSteps;
      if (computed >= 0) {
        _todaySteps = computed;
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

  /// Stops tracking subscriptions.
  Future<void> stop() async {
    await _stepSubscription?.cancel();
    await _statusSubscription?.cancel();
    _stepSubscription = null;
    _statusSubscription = null;
    _isListening = false;
  }
}
