import 'dart:async';

/// Monitors internet connectivity transitions and provides debounced notifications
/// when connectivity is restored, preventing rapid flapping across Wi-Fi and mobile networks.
class ConnectivityMonitor {
  ConnectivityMonitor({
    Duration debounceDuration = const Duration(seconds: 2),
    Future<bool> Function()? reachabilityProbe,
  })  : _debounceDuration = debounceDuration,
        _reachabilityProbe = reachabilityProbe;

  final Duration _debounceDuration;
  final Future<bool> Function()? _reachabilityProbe;

  bool _isOnline = true;
  Timer? _debounceTimer;
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  /// Stream emitting events when connectivity transitions from offline to online.
  Stream<bool> get onConnectivityRestored =>
      _connectivityController.stream.where((isOnline) => isOnline);

  /// Current online status.
  bool get isOnline => _isOnline;

  /// Notifies the monitor of an observed network status change.
  /// Debounces rapid network events (e.g. Wi-Fi / cellular handover) before triggering sync.
  void notifyConnectivityChange(bool isOnline) {
    if (_isOnline == isOnline) return;
    _isOnline = isOnline;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      if (_isOnline) {
        // If an explicit reachability probe is configured, verify server connectivity
        final probe = _reachabilityProbe;
        if (probe != null) {
          try {
            final isReachable = await probe();
            if (!isReachable) {
              return;
            }
          } catch (_) {
            return;
          }
        }
        if (!_connectivityController.isClosed) {
          _connectivityController.add(true);
        }
      } else {
        if (!_connectivityController.isClosed) {
          _connectivityController.add(false);
        }
      }
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
    _connectivityController.close();
  }
}

