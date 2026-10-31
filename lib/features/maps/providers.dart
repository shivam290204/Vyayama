import 'dart:async';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/saved_routes_repository.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/models/user_location_state.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
import 'package:fitbuddy/features/maps/domain/services/outdoor_session_recovery_service.dart';
import 'package:fitbuddy/features/maps/domain/services/outdoor_sync_coordinator.dart';
import 'package:fitbuddy/features/maps/domain/services/route_discovery_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

final localOutdoorStorageProvider = Provider<LocalOutdoorStorage>((ref) {
  return const LocalOutdoorStorage();
});

final outdoorActivityRepositoryProvider =
    Provider<OutdoorActivityRepository>((ref) {
  final storage = ref.watch(localOutdoorStorageProvider);
  return OutdoorActivityRepository(storage: storage);
});

final savedRoutesRepositoryProvider = Provider<SavedRoutesRepository>((ref) {
  final storage = ref.watch(localOutdoorStorageProvider);
  return SavedRoutesRepository(storage: storage);
});

final outdoorSyncCoordinatorProvider = Provider<OutdoorSyncCoordinator>((ref) {
  final actRepo = ref.watch(outdoorActivityRepositoryProvider);
  final routesRepo = ref.watch(savedRoutesRepositoryProvider);
  return OutdoorSyncCoordinator(
    activityRepository: actRepo,
    routesRepository: routesRepo,
  );
});

final routeDiscoveryEngineProvider = Provider<RouteDiscoveryEngine>((ref) {
  return RouteDiscoveryEngine();
});

final outdoorSessionRecoveryServiceProvider =
    Provider<OutdoorSessionRecoveryService>((ref) {
  return OutdoorSessionRecoveryService();
});

final activeOutdoorCheckpointProvider =
    FutureProvider<OutdoorSessionCheckpoint?>((ref) async {
  final recoveryService = ref.watch(outdoorSessionRecoveryServiceProvider);
  return recoveryService.getActiveCheckpoint();
});

final locationTrackingServiceProvider =
    Provider<LocationTrackingService>((ref) {
  final repository = ref.watch(outdoorActivityRepositoryProvider);
  final recoveryService = ref.watch(outdoorSessionRecoveryServiceProvider);
  final service = LocationTrackingService(
    filterService: const GpsFilterService(),
    repository: repository,
    recoveryService: recoveryService,
  );
  ref.onDispose(service.dispose);
  return service;
});

final trackingStateProvider = StreamProvider<TrackingState>((ref) {
  final service = ref.watch(locationTrackingServiceProvider);
  final controller = StreamController<TrackingState>();

  void listener() {
    if (!controller.isClosed) {
      controller.add(service.value);
    }
  }

  service.addListener(listener);
  controller.add(service.value);

  ref.onDispose(() {
    service.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

/// StateNotifier managing unified, high-accuracy user location state.
class UserLocationNotifier extends StateNotifier<UserLocationState> {
  UserLocationNotifier(this._service) : super(UserLocationState.initial) {
    refreshLocation();
  }

  final LocationTrackingService _service;

  /// Acquires or refreshes the user's GPS position with deduplicated queries.
  /// When [requestIfNeeded] is false (default on startup), it does not trigger the OS
  /// prompt automatically, allowing the app to show a plain-language disclosure first.
  Future<void> refreshLocation({bool requestIfNeeded = false}) async {
    // Preserve any existing position as lastKnownPosition while refreshing
    state = state.copyWith(
      status: UserLocationStatus.waitingForSignal,
      lastKnownPosition: state.position ?? state.lastKnownPosition,
    );

    // Fast-path: read last known position from OS cache if no position is known yet
    if (state.lastKnownPosition == null) {
      final lastKnown = await _service.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        state = state.copyWith(lastKnownPosition: lastKnown);
      }
    }

    final perm = await _service.checkPermissionDetailed(
      requestIfNeeded: requestIfNeeded,
    );
    if (!mounted) return;

    switch (perm) {
      case LocationPermissionResult.serviceDisabled:
        state = state.copyWith(
          status: UserLocationStatus.serviceDisabled,
          errorMessage: 'Location services are disabled on this device.',
        );
        return;
      case LocationPermissionResult.unavailable:
        state = state.copyWith(
          status: UserLocationStatus.unavailable,
          errorMessage:
              'Location services or hardware are unavailable on this device.',
        );
        return;
      case LocationPermissionResult.denied:
        state = state.copyWith(
          status: UserLocationStatus.permissionDenied,
          errorMessage: 'Location permission was denied.',
        );
        return;
      case LocationPermissionResult.deniedForever:
        state = state.copyWith(
          status: UserLocationStatus.permissionDeniedForever,
          errorMessage:
              'Location permission permanently denied. Please enable in settings.',
        );
        return;
      case LocationPermissionResult.granted:
        break;
    }

    try {
      final pos = await _service.getCurrentPosition();
      if (!mounted) return;
      if (pos != null) {
        state = state.copyWith(
          status: UserLocationStatus.available,
          position: pos,
          lastKnownPosition: pos,
          timestamp: DateTime.now(),
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: UserLocationStatus.timedOut,
          errorMessage: 'Could not acquire GPS position.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: UserLocationStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Explicitly requests location permission after the user has seen the plain-language disclosure.
  Future<void> requestPermission() async {
    await refreshLocation(requestIfNeeded: true);
  }
}

final userLocationNotifierProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocationState>((ref) {
  final service = ref.watch(locationTrackingServiceProvider);
  return UserLocationNotifier(service);
});

final userLocationStateProvider = Provider<UserLocationState>((ref) {
  return ref.watch(userLocationNotifierProvider);
});

/// Exposes the current verified GPS position (or null if not acquired).
/// Does not trigger duplicate requests when watched by multiple widgets.
final userCurrentLocationProvider = Provider<LatLng?>((ref) {
  return ref.watch(userLocationStateProvider).position;
});

final outdoorActivitiesListProvider =
    FutureProvider<List<OutdoorActivity>>((ref) async {
  final repo = ref.watch(outdoorActivityRepositoryProvider);
  return repo.getAllActivities();
});

final savedRoutesListProvider = FutureProvider<List<SavedRoute>>((ref) async {
  final repo = ref.watch(savedRoutesRepositoryProvider);
  return repo.getSavedRoutes();
});

final activeRouteFilterProvider = StateProvider<RouteFilter>((ref) {
  return const RouteFilter();
});

/// Holds an explicitly chosen manual search center (e.g. from search or map drag).
/// Defaults to null. When null, the system uses the live user GPS position.
final selectedMapCenterProvider = StateProvider<LatLng?>((ref) {
  return null;
});

/// The effective geographic center for route discovery:
/// 1. An explicitly selected manual center (if set by the user).
/// 2. Otherwise, the verified user GPS location (if available).
/// 3. Otherwise null (discovery is paused until a location is known).
final effectiveMapCenterProvider = Provider<LatLng?>((ref) {
  final manualCenter = ref.watch(selectedMapCenterProvider);
  if (manualCenter != null) return manualCenter;
  final locState = ref.watch(userLocationStateProvider);
  return locState.position ?? locState.lastKnownPosition;
});

/// Discovered routes near the effective center.
/// Streams verified routes progressively as candidate batches complete.
/// NEVER queries using arbitrary fallback coordinates.
final discoveredRoutesProvider = StreamProvider<List<SavedRoute>>((ref) async* {
  final engine = ref.watch(routeDiscoveryEngineProvider);
  final center = ref.watch(effectiveMapCenterProvider);
  final filter = ref.watch(activeRouteFilterProvider);

  ref.onDispose(() {
    engine.cancelCurrentDiscovery();
  });

  // If no legitimate location is known yet, yield empty list without querying the network.
  if (center == null) {
    yield const [];
    return;
  }

  yield* engine.discoverRoutesProgressive(
    center: center,
    filter: filter,
  );
});
