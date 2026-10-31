import 'dart:async';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/domain/models/gps_point.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity_type.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:fitbuddy/features/maps/domain/services/outdoor_session_recovery_service.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Detailed result of location permission and service checks.
enum LocationPermissionResult {
  /// Location service is enabled and permission is granted (while in use or always).
  granted,

  /// Permission was denied by the user.
  denied,

  /// Permission was permanently denied by the user (requires app settings).
  deniedForever,

  /// Location services (GPS hardware / setting) are disabled on the device.
  serviceDisabled,

  /// Location hardware, sensor or service is unavailable on this device.
  unavailable,
}

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
    this.activityId,
    this.isInitializingGps = false,
    this.initializationError,
    this.fixesPerMinute = 0,
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
  final String? activityId;
  final bool isInitializingGps;
  final String? initializationError;
  final int fixesPerMinute;

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
    String? activityId,
    bool? isInitializingGps,
    String? initializationError,
    int? fixesPerMinute,
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
        activityId: activityId ?? this.activityId,
        isInitializingGps: isInitializingGps ?? this.isInitializingGps,
        initializationError: initializationError ?? this.initializationError,
        fixesPerMinute: fixesPerMinute ?? this.fixesPerMinute,
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
    activityId: null,
    isInitializingGps: false,
    initializationError: null,
    fixesPerMinute: 0,
  );
}

/// Service managing GPS subscription, pause/resume, checkpointing, and lifecycle.
class LocationTrackingService extends ValueNotifier<TrackingState> {
  LocationTrackingService({
    GpsFilterService? filterService,
    OutdoorActivityRepository? repository,
    OutdoorSessionRecoveryService? recoveryService,
  })  : _filter = filterService ?? const GpsFilterService(),
        _repository = repository,
        _recoveryService = recoveryService,
        super(TrackingState.initial);

  GpsFilterService _filter;
  final OutdoorActivityRepository? _repository;
  final OutdoorSessionRecoveryService? _recoveryService;

  StreamSubscription<Position>? _positionSub;
  Timer? _durationTimer;
  Timer? _checkpointTimer;
  DateTime? _activityStartTime;
  String? _currentActivityId;
  OutdoorActivity? _lastFinishedActivity;

  /// Flag set when resuming from pause so next coordinate establishes a fresh baseline
  /// without accumulating false distance across the paused duration.
  bool _hasResumedFromPause = false;

  /// Counter of new points added since last checkpoint was persisted.
  int _pointsSinceLastCheckpoint = 0;

  /// Rolling timestamps of received GPS fixes for diagnostic fixes/min calculation.
  final List<DateTime> _recentFixTimestamps = [];

  Future<LatLng?>? _inFlightPositionQuery;
  int _positionRequestGeneration = 0;

  /// Monotonically increasing counter incremented every time a new live position request is started.
  int get positionRequestGeneration => _positionRequestGeneration;

  /// Returns the number of GPS fixes received in the last 60 seconds (rate diagnostic).
  int get fixesPerMinute {
    _pruneFixTimestamps();
    return _recentFixTimestamps.length;
  }

  void _recordFixReceived() {
    _recentFixTimestamps.add(DateTime.now());
    _pruneFixTimestamps();
  }

  void _pruneFixTimestamps() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    _recentFixTimestamps.removeWhere((t) => t.isBefore(cutoff));
  }

  @visibleForTesting
  Future<LocationPermissionResult> Function({bool requestIfNeeded})?
      checkPermissionDetailedOverride;

  @visibleForTesting
  Future<LatLng?> Function()? getCurrentPositionOverride;

  @visibleForTesting
  Future<LatLng?> Function()? getLastKnownPositionOverride;

  @visibleForTesting
  Stream<Position> Function(LocationSettings settings)?
      getPositionStreamOverride;

  /// Performs a detailed check of location services and permissions.
  Future<LocationPermissionResult> checkPermissionDetailed({
    bool requestIfNeeded = true,
  }) async {
    if (checkPermissionDetailedOverride != null) {
      return checkPermissionDetailedOverride!(
        requestIfNeeded: requestIfNeeded,
      );
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionResult.serviceDisabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestIfNeeded) {
          return LocationPermissionResult.denied;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationPermissionResult.denied;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionResult.deniedForever;
      }

      return LocationPermissionResult.granted;
    } catch (e) {
      debugPrint('[LocationTrackingService] Permission check error: $e');
      return LocationPermissionResult.unavailable;
    }
  }

  /// Requests location permissions if needed. Returns true if granted.
  Future<bool> checkAndRequestPermission() async {
    final result = await checkPermissionDetailed();
    return result == LocationPermissionResult.granted;
  }

  /// Quickly retrieves the last known position from the OS cache without turning on GPS hardware.
  Future<LatLng?> getLastKnownPosition() async {
    if (getLastKnownPositionOverride != null) {
      return getLastKnownPositionOverride!();
    }

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        return LatLng(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('[LocationTrackingService] Error getting last known position: $e');
    }
    return null;
  }

  /// Obtains current GPS position with single in-flight deduplication.
  Future<LatLng?> getCurrentPosition() async {
    if (getCurrentPositionOverride != null) {
      return getCurrentPositionOverride!();
    }

    if (_inFlightPositionQuery != null) {
      return _inFlightPositionQuery!;
    }

    final future = _fetchPositionInternal();
    _inFlightPositionQuery = future;
    try {
      return await future;
    } finally {
      _inFlightPositionQuery = null;
    }
  }

  Future<LatLng?> _fetchPositionInternal() async {
    _positionRequestGeneration++;
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

  /// Starts live outdoor recording session after verifying permissions, service status,
  /// and acquiring an initial valid GPS satellite fix.
  Future<bool> startRecording(
    OutdoorActivityType type, {
    Duration initialFixTimeout = const Duration(seconds: 12),
  }) async {
    await stopTracking();
    _lastFinishedActivity = null;

    // 1. Indicate initialization state
    value = TrackingState(
      status: OutdoorActivityStatus.discarded,
      activityType: type,
      points: [],
      distanceMeters: 0.0,
      durationSeconds: 0,
      currentPaceSecondsPerKm: 0,
      currentSpeedKmh: 0.0,
      currentPosition: null,
      isInitializingGps: true,
      initializationError: null,
    );

    // 2. Check location hardware & service enabled
    final permResult = await checkPermissionDetailed(requestIfNeeded: true);
    if (permResult == LocationPermissionResult.serviceDisabled) {
      value = value.copyWith(
        isInitializingGps: false,
        initializationError:
            'Location services are disabled on this device. Please turn on GPS in your device settings.',
      );
      return false;
    }

    if (permResult != LocationPermissionResult.granted) {
      value = value.copyWith(
        isInitializingGps: false,
        initializationError:
            'Location permission is required to track outdoor workouts.',
      );
      return false;
    }

    // 3. Acquire initial valid GPS fix before starting workout clock
    LatLng? initialPosition;
    try {
      if (getCurrentPositionOverride != null) {
        initialPosition = await getCurrentPositionOverride!();
      } else {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: initialFixTimeout,
          ),
        );
        initialPosition = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {
      initialPosition = null;
    }

    if (initialPosition == null) {
      value = value.copyWith(
        isInitializingGps: false,
        initializationError:
            'Unable to acquire GPS fix. Please ensure you are outdoors with a clear view of the sky and try again.',
      );
      return false;
    }

    // 4. Successful initialization: configure filter, assign stable activityId, and start recording
    _currentActivityId = 'outdoor_${DateTime.now().millisecondsSinceEpoch}';
    _activityStartTime = DateTime.now();
    _filter = GpsFilterService.forActivity(type);
    _hasResumedFromPause = false;
    _pointsSinceLastCheckpoint = 0;

    final initialPoint = GpsPoint(
      latitude: initialPosition.latitude,
      longitude: initialPosition.longitude,
      timestamp: _activityStartTime!,
      accuracy: 5.0,
    );

    value = TrackingState(
      status: OutdoorActivityStatus.active,
      activityType: type,
      points: [initialPoint],
      distanceMeters: 0.0,
      durationSeconds: 0,
      currentPaceSecondsPerKm: 0,
      currentSpeedKmh: 0.0,
      currentPosition: initialPosition,
      startTime: _activityStartTime,
      activityId: _currentActivityId,
      isInitializingGps: false,
      initializationError: null,
      fixesPerMinute: 1,
    );
    _recordFixReceived();

    // 5. Start active duration timer
    _startDurationTimer();

    // 6. Start periodic 30-second checkpoint timer for crash recovery
    _startCheckpointTimer();
    _saveCheckpoint();

    // 7. Start live high-accuracy GPS position stream (exactly one subscription)
    _startPositionStream(type);

    return true;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
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
          fixesPerMinute: fixesPerMinute,
        );
      }
    });
  }

  void _startCheckpointTimer() {
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (value.status == OutdoorActivityStatus.active ||
          value.status == OutdoorActivityStatus.paused) {
        _saveCheckpoint();
      }
    });
  }

  Future<void> _saveCheckpoint() async {
    if (_recoveryService == null || _currentActivityId == null) return;
    final checkpoint = OutdoorSessionCheckpoint(
      activityId: _currentActivityId!,
      activityType: value.activityType,
      status: value.status,
      startTime: _activityStartTime ?? DateTime.now(),
      durationSeconds: value.durationSeconds,
      distanceMeters: value.distanceMeters,
      points: List.unmodifiable(value.points),
      elevationGainMeters: _filter.calculateElevationGain(value.points),
      lastCheckpointTime: DateTime.now(),
    );
    await _recoveryService.saveCheckpoint(checkpoint);
    _pointsSinceLastCheckpoint = 0;
  }

  void _startPositionStream(OutdoorActivityType type) {
    _positionSub?.cancel();
    final settings = _buildLocationSettings(type);

    final Stream<Position> stream = getPositionStreamOverride != null
        ? getPositionStreamOverride!(settings)
        : Geolocator.getPositionStream(locationSettings: settings);

    _positionSub = stream.listen(
      _onPositionUpdate,
      onError: (err) {
        debugPrint('[LocationTrackingService] GPS stream error: $err');
      },
    );
  }

  /// Builds activity-tailored location settings for optimal battery and tracking precision.
  LocationSettings _buildLocationSettings(OutdoorActivityType type) {
    int distanceFilter;
    Duration interval;
    const accuracy = LocationAccuracy.bestForNavigation;

    switch (type) {
      case OutdoorActivityType.walking:
      case OutdoorActivityType.hiking:
        distanceFilter = 4; // 4 meters
        interval = const Duration(seconds: 3);
        break;
      case OutdoorActivityType.running:
        distanceFilter = 3; // 3 meters
        interval = const Duration(seconds: 2);
        break;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: interval,
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
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );
  }

  void _onPositionUpdate(Position pos) {
    _recordFixReceived();

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

    // Check if resuming from pause: if so, establish new baseline without adding distance
    final isResuming = _hasResumedFromPause;
    if (_filter.isValidNextPoint(lastPoint, candidate, isResumingFromPause: isResuming)) {
      _hasResumedFromPause = false;

      final updatedPoints = List<GpsPoint>.from(value.points)..add(candidate);
      final addedDistance = (lastPoint != null && !isResuming)
          ? _filter.distanceBetween(lastPoint, candidate)
          : 0.0;
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
        fixesPerMinute: fixesPerMinute,
      );

      _pointsSinceLastCheckpoint++;
      if (_pointsSinceLastCheckpoint >= 10) {
        _saveCheckpoint();
      }
    } else {
      // Update visual marker even if point was rejected for drift/jitter
      value = value.copyWith(
        currentPosition: candidate.toLatLng(),
        fixesPerMinute: fixesPerMinute,
      );
    }
  }

  /// Pauses the recording session: stops timer, sets pause status, and saves checkpoint.
  void pauseRecording() {
    if (value.status == OutdoorActivityStatus.active) {
      _durationTimer?.cancel();
      _durationTimer = null;
      _hasResumedFromPause = true;

      value = value.copyWith(status: OutdoorActivityStatus.paused);
      _saveCheckpoint();
    }
  }

  /// Resumes the paused recording session: restarts timer and marks pause baseline.
  void resumeRecording() {
    if (value.status == OutdoorActivityStatus.paused) {
      _hasResumedFromPause = true;
      _startDurationTimer();

      value = value.copyWith(status: OutdoorActivityStatus.active);
      _saveCheckpoint();
    }
  }

  /// Restores an unfinished session from a crash-recovery checkpoint.
  Future<bool> restoreSession(OutdoorSessionCheckpoint checkpoint) async {
    await stopTracking();

    _currentActivityId = checkpoint.activityId;
    _activityStartTime = checkpoint.startTime;
    _filter = GpsFilterService.forActivity(checkpoint.activityType);
    _hasResumedFromPause = true;

    final lastPos = checkpoint.points.isNotEmpty
        ? checkpoint.points.last.toLatLng()
        : null;

    final pace = _filter.calculateAveragePaceSeconds(
      checkpoint.distanceMeters,
      checkpoint.durationSeconds,
    );
    final speed = _filter.calculateAverageSpeedKmh(
      checkpoint.distanceMeters,
      checkpoint.durationSeconds,
    );

    // Restores in paused state so user can choose when to restart moving
    value = TrackingState(
      status: OutdoorActivityStatus.paused,
      activityType: checkpoint.activityType,
      points: checkpoint.points,
      distanceMeters: checkpoint.distanceMeters,
      durationSeconds: checkpoint.durationSeconds,
      currentPaceSecondsPerKm: pace,
      currentSpeedKmh: speed,
      currentPosition: lastPos,
      startTime: checkpoint.startTime,
      activityId: checkpoint.activityId,
      isInitializingGps: false,
      initializationError: null,
    );

    _startCheckpointTimer();
    _startPositionStream(checkpoint.activityType);
    return true;
  }

  /// Finishes recording, compiles the completed OutdoorActivity, and saves locally immediately.
  /// Idempotent: repeated finish calls return the saved activity without duplicate entries.
  Future<OutdoorActivity?> finishRecording({
    String? title,
    String userId = 'local_user',
  }) async {
    if (_lastFinishedActivity != null) {
      return _lastFinishedActivity;
    }

    if (value.status == OutdoorActivityStatus.discarded &&
        value.points.isEmpty &&
        value.durationSeconds == 0) {
      return null;
    }

    final endTime = DateTime.now();
    final startTime = _activityStartTime ?? endTime;
    final totalDistance = value.distanceMeters;
    final durationSec = value.durationSeconds;

    final elevationGain = _filter.calculateElevationGain(value.points);
    final avgPace =
        _filter.calculateAveragePaceSeconds(totalDistance, durationSec);
    final avgSpeed =
        _filter.calculateAverageSpeedKmh(totalDistance, durationSec);

    // Estimate calories: MET * weightKg (default 70kg) * hours
    final met = value.activityType.met;
    final hours = durationSec / 3600.0;
    final calories = (met * 70.0 * hours).round();

    final activity = OutdoorActivity(
      id: _currentActivityId ?? 'outdoor_${DateTime.now().millisecondsSinceEpoch}',
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

    _lastFinishedActivity = activity;

    // Immediately persist locally (offline-first guarantee)
    if (_repository != null) {
      await _repository.saveActivity(activity);
    }

    // Clean up crash recovery checkpoint
    if (_recoveryService != null) {
      await _recoveryService.clearCheckpoint();
    }

    await stopTracking();
    value = value.copyWith(status: OutdoorActivityStatus.completed);
    return activity;
  }

  /// Discards the current session without saving and cleans the checkpoint.
  void discardRecording() {
    stopTracking();
    _recoveryService?.clearCheckpoint();
    _currentActivityId = null;
    _lastFinishedActivity = null;
    value = TrackingState.initial;
  }

  /// Shuts down stream, timers, and background tasks.
  Future<void> stopTracking() async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    await _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
