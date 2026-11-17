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
  bool _hasPendingSync = false;
  String? _pendingSyncTrigger;

  /// Exposes whether a full sync coordinator run is active.
  bool get isSyncing => _isSyncing;

  /// Exposes whether a coalesced sync is queued to run after the active sync completes.
  bool get hasPendingSync => _hasPendingSync;

  void _initConnectivityListener() {
    if (_connectivityMonitor == null) return;
    _connectivitySub = _connectivityMonitor.onConnectivityRestored.listen((_) {
      syncAll(trigger: 'connectivity_restored');
    });
  }

  /// Triggers full synchronization of pending deletion tombstones, activities, and routes.
  ///
  /// If a sync is already active, records that an additional sync is required and coalesces
  /// subsequent triggers. When the current cycle finishes, it automatically runs one additional
  /// cycle with the latest trigger, preventing dropped reconnect events without duplicate or infinite loops.
  Future<OutdoorSyncResult> syncAll({String trigger = 'manual'}) async {
    if (_isSyncing) {
      _hasPendingSync = true;
      _pendingSyncTrigger = trigger;
      debugPrint(
        '[OutdoorSyncCoordinator] Sync already active. Coalesced pending trigger: $trigger',
      );
      return const OutdoorSyncResult(
        activitiesSynced: 0,
        routesSynced: 0,
        isAlreadyRunning: true,
      );
    }

    _isSyncing = true;
    _hasPendingSync = false;
    _pendingSyncTrigger = null;

    try {
      var currentTrigger = trigger;
      var totalActs = 0;
      var totalRoutes = 0;
      String? lastError;

      // Execute current sync plus at most ONE coalesced follow-up cycle if triggers arrived in-flight
      var cycles = 0;
      const maxCycles = 2;

      while (cycles < maxCycles) {
        cycles++;
        _hasPendingSync = false;
        _pendingSyncTrigger = null;

        debugPrint(
          '[OutdoorSyncCoordinator] Starting sync cycle (trigger: $currentTrigger, cycle: $cycles)',
        );

        final cycleResult = await _executeSingleCycle(currentTrigger);
        totalActs += cycleResult.activitiesSynced;
        totalRoutes += cycleResult.routesSynced;
        lastError = cycleResult.errorMessage;

        // If another trigger arrived while the cycle was executing, run one coalesced cycle
        if (_hasPendingSync) {
          currentTrigger = _pendingSyncTrigger ?? 'coalesced';
          continue;
        } else {
          break;
        }
      }

      return OutdoorSyncResult(
        activitiesSynced: totalActs,
        routesSynced: totalRoutes,
        isAlreadyRunning: false,
        errorMessage: lastError,
      );
    } finally {
      _isSyncing = false;
      _hasPendingSync = false;
      _pendingSyncTrigger = null;
    }
  }

  Future<OutdoorSyncResult> _executeSingleCycle(String trigger) async {
    try {
      // 1. Sync activities (pulls remote tombstones, processes pending tombstones, then uploads)
      final actsCount = await _activityRepo.syncPendingActivities();

      // 2. Sync saved routes (pulls remote tombstones, processes pending tombstones, then uploads)
      final routesCount = await _routesRepo.syncPendingRoutes();

      debugPrint(
        '[OutdoorSyncCoordinator] Cycle complete ($trigger): $actsCount activities, $routesCount routes.',
      );

      return OutdoorSyncResult(
        activitiesSynced: actsCount,
        routesSynced: routesCount,
        isAlreadyRunning: false,
      );
    } catch (e) {
      debugPrint('[OutdoorSyncCoordinator] Sync cycle error ($trigger): $e');
      return OutdoorSyncResult(
        activitiesSynced: 0,
        routesSynced: 0,
        isAlreadyRunning: false,
        errorMessage: e.toString(),
      );
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
  }
}
