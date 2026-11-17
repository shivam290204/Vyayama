import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Types of network connections available to the device.
enum NetworkConnectionType {
  wifi,
  mobile,
  other,
  none,
}

/// Explicit verification status of internet reachability.
enum NetworkReachabilityStatus {
  online,
  offline,
  unknown,
}

/// Monitors internet connectivity transitions and provides debounced notifications
/// when connectivity is restored, preventing rapid flapping across Wi-Fi and mobile networks.
class ConnectivityMonitor with WidgetsBindingObserver {
  ConnectivityMonitor({
    Duration debounceDuration = const Duration(seconds: 2),
    FutureOr<dynamic> Function()? reachabilityProbe,
    NetworkConnectionType initialConnectionType = NetworkConnectionType.other,
    bool initialOnline = true,
    Connectivity? connectivity,
    Stream<List<ConnectivityResult>>? connectivityStream,
    Future<List<ConnectivityResult>> Function()? checkConnectivityFn,
    bool enablePlatformListener = false,
    int maxUnknownRetries = 3,
    Duration unknownRetryInterval = const Duration(seconds: 2),
  })  : _debounceDuration = debounceDuration,
        _reachabilityProbe = reachabilityProbe,
        _maxUnknownRetries = maxUnknownRetries,
        _unknownRetryInterval = unknownRetryInterval,
        _connectionType =
            initialOnline ? initialConnectionType : NetworkConnectionType.none,
        _isOnline = initialOnline,
        _connectivity = connectivity,
        _connectivityStream = connectivityStream,
        _checkConnectivityFn = checkConnectivityFn {
    if (enablePlatformListener ||
        connectivity != null ||
        connectivityStream != null ||
        checkConnectivityFn != null) {
      _initPlatformListener();
    }
  }

  final Duration _debounceDuration;
  final FutureOr<dynamic> Function()? _reachabilityProbe;
  final int _maxUnknownRetries;
  final Duration _unknownRetryInterval;
  final Connectivity? _connectivity;
  final Stream<List<ConnectivityResult>>? _connectivityStream;
  final Future<List<ConnectivityResult>> Function()? _checkConnectivityFn;

  bool _isOnline;
  NetworkConnectionType _connectionType;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  int _connectivityGeneration = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _observerRegistered = false;
  bool _isDisposed = false;
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  /// Stream emitting events when connectivity transitions from offline to online.
  Stream<bool> get onConnectivityRestored =>
      _connectivityController.stream.where((isOnline) => isOnline);

  /// Current online status.
  bool get isOnline => _isOnline;

  /// Current network connection transport type.
  NetworkConnectionType get connectionType => _connectionType;

  /// Whether this monitor has been disposed.
  bool get isDisposed => _isDisposed;

  /// Default internet reachability probe verifying real DNS resolution.
  ///
  /// - Returns [NetworkReachabilityStatus.online] if either primary (dns.google)
  ///   or fallback (cloudflare.com) resolves successfully.
  /// - Returns [NetworkReachabilityStatus.unknown] if DNS lookups fail or time out
  ///   (never returns offline or false, because DNS failure is not definitive proof
  ///   that the device has no network connection).
  static Future<NetworkReachabilityStatus> defaultReachabilityProbe() async {
    return probeDnsReachability((host) => InternetAddress.lookup(host));
  }

  /// Probe helper that executes DNS queries against primary and fallback hosts.
  static Future<NetworkReachabilityStatus> probeDnsReachability(
    Future<List<InternetAddress>> Function(String host) lookup,
  ) async {
    try {
      final res = await lookup('dns.google')
          .timeout(const Duration(milliseconds: 1500));
      if (res.isNotEmpty && res[0].rawAddress.isNotEmpty) {
        return NetworkReachabilityStatus.online;
      }
    } catch (_) {
      // Primary DNS lookup failed, try fallback.
    }

    try {
      final fallback = await lookup('cloudflare.com')
          .timeout(const Duration(milliseconds: 1500));
      if (fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty) {
        return NetworkReachabilityStatus.online;
      }
    } catch (_) {
      // Fallback DNS lookup failed.
    }

    return NetworkReachabilityStatus.unknown;
  }

  static NetworkReachabilityStatus _normalizeReachability(dynamic result) {
    if (result == true || result == NetworkReachabilityStatus.online) {
      return NetworkReachabilityStatus.online;
    }
    if (result == false || result == NetworkReachabilityStatus.offline) {
      return NetworkReachabilityStatus.offline;
    }
    return NetworkReachabilityStatus.unknown;
  }

  /// Notifies the monitor of an observed network status change.
  /// Debounces rapid network events (e.g. Wi-Fi / cellular handover) before triggering sync.
  void notifyConnectivityChange(
    bool isOnline, {
    NetworkConnectionType? connectionType,
  }) {
    if (_isDisposed) return;
    if (connectionType != null) {
      _connectionType = connectionType;
    } else if (!isOnline) {
      _connectionType = NetworkConnectionType.none;
    }
    if (_isOnline == isOnline) return;
    _isOnline = isOnline;

    final token = ++_connectivityGeneration;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();

    _debounceTimer = Timer(_debounceDuration, () {
      if (_isDisposed || _connectivityGeneration != token) return;
      if (_isOnline) {
        _executeReconnectCheck(token, attempt: 0);
      } else {
        if (!_connectivityController.isClosed) {
          _connectivityController.add(false);
        }
      }
    });
  }

  Future<void> _executeReconnectCheck(int token, {int attempt = 0}) async {
    if (_isDisposed || _connectivityGeneration != token || !_isOnline) return;

    var status = NetworkReachabilityStatus.online;
    final probe = _reachabilityProbe;
    if (probe != null) {
      try {
        final result = await probe();
        status = _normalizeReachability(result);
      } catch (_) {
        status = NetworkReachabilityStatus.unknown;
      }
    }

    // Verify monitor state and generation after async gap to prevent stale callbacks
    if (_isDisposed || _connectivityGeneration != token || !_isOnline) return;

    if (status == NetworkReachabilityStatus.online) {
      if (!_connectivityController.isClosed) {
        _connectivityController.add(true);
      }
      return;
    }

    // If reachability is unknown, do not abandon reconnect: schedule a bounded retry
    if (status == NetworkReachabilityStatus.unknown &&
        attempt < _maxUnknownRetries) {
      _retryTimer?.cancel();
      _retryTimer = Timer(_unknownRetryInterval, () {
        _executeReconnectCheck(token, attempt: attempt + 1);
      });
    }
  }

  /// Checks whether internet connectivity is currently established and reachable.
  ///
  /// - Returns [NetworkReachabilityStatus.offline] if explicitly marked offline
  ///   (no network connection or disconnected interface).
  /// - Returns [NetworkReachabilityStatus.online] if verified reachable.
  /// - Returns [NetworkReachabilityStatus.unknown] if probe fails, throws, or is indeterminate
  ///   (never falsely assumes offline on probe failure).
  Future<NetworkReachabilityStatus> checkReachability() async {
    // If explicitly marked offline (no network, disconnected interface), it is definitely offline.
    if (!_isOnline || _connectionType == NetworkConnectionType.none) {
      return NetworkReachabilityStatus.offline;
    }

    final probe = _reachabilityProbe;
    if (probe != null) {
      try {
        final result = await probe();
        return _normalizeReachability(result);
      } catch (_) {
        // Requirement 3 & 4: Do not classify a failed connectivity probe as definitely offline.
        // Handle unknown connectivity separately.
        return NetworkReachabilityStatus.unknown;
      }
    }

    return NetworkReachabilityStatus.unknown;
  }

  void _initPlatformListener() {
    final stream = _connectivityStream ??
        (_connectivity ?? Connectivity()).onConnectivityChanged;
    _connectivitySubscription =
        stream.listen(_handlePlatformConnectivityChanged);
    refreshConnectivity();
    try {
      WidgetsBinding.instance.addObserver(this);
      _observerRegistered = true;
    } catch (_) {
      // Ignored in headless/unit-test environments where WidgetsBinding is not initialized
    }
  }

  /// Refreshes current network transport status from platform connectivity service.
  Future<void> refreshConnectivity() async {
    if (_isDisposed) return;
    try {
      final check = _checkConnectivityFn ??
          (_connectivity ?? Connectivity()).checkConnectivity;
      final results = await check();
      if (_isDisposed) return;
      _handlePlatformConnectivityChanged(results);
    } catch (_) {
      // Platform channels may be unavailable in unit test environments without mocks
    }
  }

  void _handlePlatformConnectivityChanged(List<ConnectivityResult> results) {
    if (_isDisposed) return;
    final isNone =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (isNone) {
      notifyConnectivityChange(false, connectionType: NetworkConnectionType.none);
    } else if (results.contains(ConnectivityResult.wifi)) {
      notifyConnectivityChange(true, connectionType: NetworkConnectionType.wifi);
    } else if (results.contains(ConnectivityResult.mobile)) {
      notifyConnectivityChange(true, connectionType: NetworkConnectionType.mobile);
    } else {
      notifyConnectivityChange(true, connectionType: NetworkConnectionType.other);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    if (state == AppLifecycleState.resumed) {
      refreshConnectivity();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    if (_observerRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _observerRegistered = false;
    }
    _connectivityController.close();
  }
}

