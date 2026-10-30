import 'dart:async';
import 'package:fitbuddy/features/maps/data/repositories/local_outdoor_storage.dart';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/saved_routes_repository.dart';
import 'package:fitbuddy/features/maps/domain/models/outdoor_activity.dart';
import 'package:fitbuddy/features/maps/domain/models/route_filter.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:fitbuddy/features/maps/domain/services/gps_filter_service.dart';
import 'package:fitbuddy/features/maps/domain/services/location_tracking_service.dart';
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

final routeDiscoveryEngineProvider = Provider<RouteDiscoveryEngine>((ref) {
  return const RouteDiscoveryEngine();
});

final locationTrackingServiceProvider =
    Provider<LocationTrackingService>((ref) {
  final service = LocationTrackingService(
    filterService: const GpsFilterService(),
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

final userCurrentLocationProvider = FutureProvider<LatLng?>((ref) async {
  final service = ref.watch(locationTrackingServiceProvider);
  return service.getCurrentPosition();
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

final selectedMapCenterProvider = StateProvider<LatLng>((ref) {
  // Default fallback center: scenic Central Park coordinates if GPS not yet loaded
  return const LatLng(40.785091, -73.968285);
});

final discoveredRoutesProvider = FutureProvider<List<SavedRoute>>((ref) async {
  final engine = ref.watch(routeDiscoveryEngineProvider);
  final center = ref.watch(selectedMapCenterProvider);
  final filter = ref.watch(activeRouteFilterProvider);

  return engine.discoverRoutes(
    center: center,
    filter: filter,
  );
});
