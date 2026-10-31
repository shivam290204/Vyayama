import 'dart:async';
import 'package:fitbuddy/features/maps/data/repositories/outdoor_activity_repository.dart';
import 'package:fitbuddy/features/maps/data/repositories/saved_routes_repository.dart';
import 'package:fitbuddy/features/maps/domain/services/connectivity_monitor.dart';
import 'package:flutter/foundation.dart';

/// Result summary of an outdoor sync cycle.
class OutdoorSyncResult {
  const OutdoorSyncResult({
    required this.activitiesSynced,
    required this.routesSynced,
    required this.isAlreadyRunning,
    this.errorMessage,
  });

  final int activitiesSynced;
  final int routesSynced;
  final bool isAlreadyRunning;
  final String? errorMessage;

  bool get isSuccess => errorMessage == null && !isAlreadyRunning;

  @override
  String toString() =>
      'OutdoorSyncResult(acts: $activitiesSynced, routes: $routesSynced, running: $isAlreadyRunning, err: $errorMessage)';
}

/// Central coordinator managing full synchronization of outdoor workout records,
/// saved routes, and pending deletion tombstones, including connectivity restoration triggers.
class OutdoorSyncCoordinator {
  OutdoorSyncCoordinator({
    required OutdoorActivityRepository activityRepository,
    required SavedRoutesRepository routesRepository,
    ConnectivityMonitor? connectivityMonitor,
  })  : _activityRepo = activityRepository,
        _routesRepo = routesRepository,
        _connectivityMonitor = connectivityMonitor {
    _initConnectivityListener();
  }

  final OutdoorActivityRepository _activityRepo;
  final SavedRoutesRepository _routesRepo;
  final ConnectivityMonitor? _connectivityMonitor;
  StreamSubscription<bool>? _connectivitySub;

  bool _isSyncing = false;

  /// Exposes whether a full sync coordinator run is active.
  bool get isSyncing => _isSyncing;

  void _initConnectivityListener() {
    if (_connectivityMonitor == null) return;
    _connectivitySub = _connectivityMonitor.onConnectivityRestored.listen((_) {
      syncAll(trigger: 'connectivity_restored');
    });
  }

  /// Triggers full synchronization of pending deletion tombstones, activities, and routes.
  /// Deduplicates concurrent triggers via an in-flight execution lock.
  Future<OutdoorSyncResult> syncAll({String trigger = 'manual'}) async {
    if (_isSyncing) {
      return const OutdoorSyncResult(
        activitiesSynced: 0,
        routesSynced: 0,
        isAlreadyRunning: true,
      );
    }

    _isSyncing = true;
    try {
      debugPrint('[OutdoorSyncCoordinator] Starting sync (trigger: $trigger)');

      // 1. Sync activities (processes activity tombstones first, then uploads)
      final actsCount = await _activityRepo.syncPendingActivities();

      // 2. Sync saved routes (processes route tombstones first, then uploads)
      final routesCount = await _routesRepo.syncPendingRoutes();

      debugPrint(
        '[OutdoorSyncCoordinator] Sync complete: $actsCount activities, $routesCount routes.',
      );

      return OutdoorSyncResult(
        activitiesSynced: actsCount,
        routesSynced: routesCount,
        isAlreadyRunning: false,
      );
    } catch (e) {
      debugPrint('[OutdoorSyncCoordinator] Sync cycle error: $e');
      return OutdoorSyncResult(
        activitiesSynced: 0,
        routesSynced: 0,
        isAlreadyRunning: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
