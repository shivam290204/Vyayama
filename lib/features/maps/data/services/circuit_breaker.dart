import 'package:fitbuddy/features/maps/data/services/route_exceptions.dart';

/// Circuit breaker operational state.
enum CircuitBreakerState {
  /// Normal operation: requests pass through.
  closed,

  /// Circuit tripped: calls fail immediately without hitting the network.
  open,

  /// Probation period: allows a single trial request to test service recovery.
  halfOpen,
}

/// A lightweight, robust Circuit Breaker to prevent retry storms and battery drain.
///
/// After [failureThreshold] consecutive failures, transitions to [CircuitBreakerState.open]
/// and fast-fails for [cooldownDuration] (default: 60s) with [CircuitBreakerOpenException].
class ServiceCircuitBreaker {
  ServiceCircuitBreaker({
    required this.serviceName,
    this.failureThreshold = 3,
    this.cooldownDuration = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String serviceName;
  final int failureThreshold;
  final Duration cooldownDuration;
  final DateTime Function() _clock;

  int _consecutiveFailures = 0;
  DateTime? _openedAt;
  CircuitBreakerState _state = CircuitBreakerState.closed;

  /// Current circuit state.
  CircuitBreakerState get state {
    if (_state == CircuitBreakerState.open) {
      if (_clock().difference(_openedAt!) >= cooldownDuration) {
        _state = CircuitBreakerState.halfOpen;
      }
    }
    return _state;
  }

  /// Whether the circuit is currently open (blocking calls).
  bool get isOpen => state == CircuitBreakerState.open;

  /// Number of consecutive failures currently tracked.
  int get failureCount => _consecutiveFailures;

  /// Remaining cooldown time if open.
  Duration get remainingCooldown {
    if (_openedAt == null) return Duration.zero;
    final elapsed = _clock().difference(_openedAt!);
    final remaining = cooldownDuration - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Guards an operation: throws [CircuitBreakerOpenException] if the circuit is open.
  void protect() {
    if (isOpen) {
      throw CircuitBreakerOpenException(
        serviceName: serviceName,
        cooldownRemaining: remainingCooldown,
      );
    }
  }

  /// Records a successful operation: resets failures and closes the circuit.
  void recordSuccess() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _state = CircuitBreakerState.closed;
  }

  /// Records a failure: trips the circuit when threshold is reached.
  void recordFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= failureThreshold) {
      _state = CircuitBreakerState.open;
      _openedAt = _clock();
    }
  }

  /// Resets the circuit breaker state (useful for testing).
  void reset() {
    _consecutiveFailures = 0;
    _openedAt = null;
    _state = CircuitBreakerState.closed;
  }
}
