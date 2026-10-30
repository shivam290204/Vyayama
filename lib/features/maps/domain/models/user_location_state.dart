import 'package:latlong2/latlong.dart';

/// Distinct lifecycle and accuracy states for user GPS location.
enum UserLocationStatus {
  /// Initial state before any location request has been started.
  initializing,

  /// Location permission granted and actively acquiring GPS fix or waiting for satellites.
  waitingForSignal,

  /// Valid, high-accuracy GPS fix acquired.
  available,

  /// Device location hardware / service is switched off in system settings.
  serviceDisabled,

  /// Permission denied by the user.
  permissionDenied,

  /// Permission permanently denied by the user (requires system settings).
  permissionDeniedForever,

  /// GPS fix attempt timed out before acquiring coordinates.
  timedOut,

  /// Hardware, OS, or unknown platform exception occurred.
  failed,
}

/// Immutable state snapshot representing the user's location status, coordinates, and diagnostics.
class UserLocationState {
  const UserLocationState({
    required this.status,
    this.position,
    this.lastKnownPosition,
    this.accuracyMeters,
    this.altitude,
    this.speed,
    this.heading,
    this.timestamp,
    this.errorMessage,
  });

  /// Current lifecycle / permission / fix status.
  final UserLocationStatus status;

  /// Current accurate GPS position, non-null only when [status] is [UserLocationStatus.available].
  final LatLng? position;

  /// Last known cached position if available, preserved during signal re-acquisition.
  final LatLng? lastKnownPosition;

  /// Estimated horizontal accuracy in meters (lower is better).
  final double? accuracyMeters;

  /// Altitude in meters above the WGS 84 reference ellipsoid.
  final double? altitude;

  /// Instantaneous speed in meters per second.
  final double? speed;

  /// Heading in degrees (0.0 to 360.0).
  final double? heading;

  /// When this coordinate fix was acquired.
  final DateTime? timestamp;

  /// User-friendly explanation if in an error or denied state.
  final String? errorMessage;

  /// Whether a verified current fix is available right now.
  bool get isAvailable =>
      status == UserLocationStatus.available && position != null;

  /// Whether either a live position or a cached last-known position is present.
  bool get hasPosition => position != null || lastKnownPosition != null;

  /// Convenient access to the best available position (current fix preferred, fallback to last known).
  LatLng? get bestAvailablePosition => position ?? lastKnownPosition;

  /// Whether the location engine is currently resolving or waiting for a GPS fix.
  bool get isResolving =>
      status == UserLocationStatus.initializing ||
      status == UserLocationStatus.waitingForSignal;

  /// Whether a permission issue prevents acquiring location.
  bool get hasPermissionIssue =>
      status == UserLocationStatus.permissionDenied ||
      status == UserLocationStatus.permissionDeniedForever;

  UserLocationState copyWith({
    UserLocationStatus? status,
    LatLng? position,
    LatLng? lastKnownPosition,
    double? accuracyMeters,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? timestamp,
    String? errorMessage,
  }) {
    return UserLocationState(
      status: status ?? this.status,
      position: position ?? this.position,
      lastKnownPosition: lastKnownPosition ?? this.lastKnownPosition,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static const initial = UserLocationState(
    status: UserLocationStatus.initializing,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserLocationState &&
        other.status == status &&
        other.position == position &&
        other.lastKnownPosition == lastKnownPosition &&
        other.accuracyMeters == accuracyMeters &&
        other.altitude == altitude &&
        other.speed == speed &&
        other.heading == heading &&
        other.timestamp == timestamp &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
        status,
        position,
        lastKnownPosition,
        accuracyMeters,
        altitude,
        speed,
        heading,
        timestamp,
        errorMessage,
      );

  @override
  String toString() =>
      'UserLocationState($status, pos: $position, lastKnown: $lastKnownPosition, err: $errorMessage)';
}
