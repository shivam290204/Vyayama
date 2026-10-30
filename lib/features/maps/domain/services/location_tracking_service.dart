import 'dart:async';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// State snapshot for live GPS outdoor activity tracking.
class TrackingState {
  const TrackingState({
    required this.status,
    required this.activityType,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.currentPaceSecondsPerKm,
    required this.currentSpeedKmh,
    required this.currentPosition,
    this.startTime,
  });

  final OutdoorActivityStatus status;
  final OutdoorActivityType activityType;
  final List<GpsPoint> points;
  final double distanceMeters;
  final int durationSeconds;
  final int currentPaceSecondsPerKm;
  final double currentSpeedKmh;
  final LatLng? currentPosition;
  final DateTime? startTime;

  double get distanceKm => distanceMeters / 1000.0;

  String get formattedDistance => distanceKm.toStringAsFixed(2);

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final mins = (durationSeconds % 3600) ~/ 60;
    final secs = durationSeconds % 60;
    if (hours > 0) {
      return '$hours:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get formattedPace {
    if (currentPaceSecondsPerKm <= 0 || currentPaceSecondsPerKm > 3600) {
      return '--:--';
    }
    final mins = currentPaceSecondsPerKm ~/ 60;
    final secs = currentPaceSecondsPerKm % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  TrackingState copyWith({
    OutdoorActivityStatus? status,
    OutdoorActivityType? activityType,
    List<GpsPoint>? points,
    double? distanceMeters,
    int? durationSeconds,
    int? currentPaceSecondsPerKm,
    double? currentSpeedKmh,
    LatLng? currentPosition,
    DateTime? startTime,
  }) =>
      TrackingState(
        status: status ?? this.status,
        activityType: activityType ?? this.activityType,
        points: points ?? this.points,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        currentPaceSecondsPerKm:
            currentPaceSecondsPerKm ?? this.currentPaceSecondsPerKm,
        currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
        currentPosition: currentPosition ?? this.currentPosition,
        startTime: startTime ?? this.startTime,
      );

  static const initial = TrackingState(
    status: OutdoorActivityStatus.discarded,
    activityType: OutdoorActivityType.walking,
    points: [],
    distanceMeters: 0.0,
    durationSeconds: 0,
    currentPaceSecondsPerKm: 0,
    currentSpeedKmh: 0.0,
    currentPosition: null,
  );
}

/// Service managing GPS subscription, pause/resume, and state changes.
class LocationTrackingService extends ValueNotifier<TrackingState> {
  LocationTrackingService({GpsFilterService? filterService})
      : _filter = filterService ?? const GpsFilterService(),
        super(TrackingState.initial);

  final GpsFilterService _filter;
  StreamSubscription<Position>? _positionSub;
  Timer? _durationTimer;
  DateTime? _activityStartTime;

  /// Requests location permissions if needed.
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtains current GPS position.
  Future<LatLng?> getCurrentPosition() async {
    try {
      final hasPerm = await checkAndRequestPermission();
      if (!hasPerm) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('[LocationTrackingService] Error getting current position: $e');
      return null;
    }
  }

  /// Starts live outdoor recording session.
  Future<bool> startRecording(OutdoorActivityType type) async {
    final hasPerm = await checkAndRequestPermission();
    if (!hasPerm) return false;

    await stopTracking();

    _activityStartTime = DateTime.now();

    value = TrackingState(
      status: OutdoorActivityStatus.active,
      activityType: type,
      points: [],
      distanceMeters: 0.0,
      durationSeconds: 0,
      currentPaceSecondsPerKm: 0,
      currentSpeedKmh: 0.0,
      currentPosition: null,
      startTime: _activityStartTime,
    );

    // Start 1-second elapsed duration timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (value.status == OutdoorActivityStatus.active) {
        final newDuration = value.durationSeconds + 1;
        final pace = _filter.calculateAveragePaceSeconds(
          value.distanceMeters,
          newDuration,
        );
        final speed = _filter.calculateAverageSpeedKmh(
          value.distanceMeters,
          newDuration,
        );

        value = value.copyWith(
          durationSeconds: newDuration,
          currentPaceSecondsPerKm: pace,
          currentSpeedKmh: speed,
        );
      }
    });

    // Start high-accuracy GPS stream with platform-specific foreground and background settings
    final locationSettings = _buildLocationSettings();

    _positionSub = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen(
      _onPositionUpdate,
      onError: (err) {
        debugPrint('[LocationTrackingService] GPS stream error: $err');
      },
    );

    return true;
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Vyayama — Outdoor Tracking',
          notificationText: 'Tracking your outdoor activity with live GPS.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );
  }

  void _onPositionUpdate(Position pos) {
    if (value.status != OutdoorActivityStatus.active) return;

    final candidate = GpsPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      timestamp: pos.timestamp,
    );

    final lastPoint = value.points.isNotEmpty ? value.points.last : null;

    if (_filter.isValidNextPoint(lastPoint, candidate)) {
      final updatedPoints = List<GpsPoint>.from(value.points)..add(candidate);
      final addedDistance =
          lastPoint != null ? _filter.distanceBetween(lastPoint, candidate) : 0.0;
      final newDistance = value.distanceMeters + addedDistance;

      final pace = _filter.calculateAveragePaceSeconds(
        newDistance,
        value.durationSeconds,
      );
      final speed = _filter.calculateAverageSpeedKmh(
        newDistance,
        value.durationSeconds,
      );

      value = value.copyWith(
        points: updatedPoints,
        distanceMeters: newDistance,
        currentPosition: candidate.toLatLng(),
        currentPaceSecondsPerKm: pace,
        currentSpeedKmh: speed,
      );
    } else {
      // Still update current visual position marker even if point was filtered for drift
      value = value.copyWith(
        currentPosition: candidate.toLatLng(),
      );
    }
  }

  /// Pauses the recording session.
  void pauseRecording() {
    if (value.status == OutdoorActivityStatus.active) {
      value = value.copyWith(status: OutdoorActivityStatus.paused);
    }
  }

  /// Resumes the paused recording session.
  void resumeRecording() {
    if (value.status == OutdoorActivityStatus.paused) {
      value = value.copyWith(status: OutdoorActivityStatus.active);
    }
  }

  /// Finishes recording and compiles the completed OutdoorActivity.
  OutdoorActivity? finishRecording({String? title, String userId = 'local_user'}) {
    if (value.status == OutdoorActivityStatus.discarded) return null;

    final endTime = DateTime.now();
    final startTime = _activityStartTime ?? endTime;
    final totalDistance = value.distanceMeters;
    final durationSec = value.durationSeconds;

    final elevationGain = _filter.calculateElevationGain(value.points);
    final avgPace = _filter.calculateAveragePaceSeconds(totalDistance, durationSec);
    final avgSpeed = _filter.calculateAverageSpeedKmh(totalDistance, durationSec);

    // Estimate calories: MET * weightKg (default 70kg) * hours
    final met = value.activityType.met;
    final hours = durationSec / 3600.0;
    final calories = (met * 70.0 * hours).round();

    final activity = OutdoorActivity(
      id: 'outdoor_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      activityType: value.activityType,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: durationSec,
      distanceMeters: totalDistance,
      averagePaceSecondsPerKm: avgPace,
      averageSpeedKmh: avgSpeed,
      points: List.unmodifiable(value.points),
      elevationGainMeters: elevationGain,
      caloriesBurned: calories,
      status: OutdoorActivityStatus.completed,
      title: title ?? '${value.activityType.label} Activity',
      isSynced: false,
    );

    stopTracking();
    return activity;
  }

  /// Discards the current session without saving.
  void discardRecording() {
    stopTracking();
    value = TrackingState.initial;
  }

  /// Shuts down stream and timers.
  Future<void> stopTracking() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

