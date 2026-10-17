import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod provider for whether the app is currently displaying in Android Picture-in-Picture mode.
final pipModeProvider = NotifierProvider<PipModeNotifier, bool>(PipModeNotifier.new);

class PipModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = SystemFeaturesService.instance;
    service.pipModeNotifier.addListener(_onPipChanged);
    ref.onDispose(() {
      service.pipModeNotifier.removeListener(_onPipChanged);
    });
    return service.pipModeNotifier.value;
  }

  void _onPipChanged() {
    state = SystemFeaturesService.instance.pipModeNotifier.value;
  }
}

/// System service handling Android-specific special app features:
/// 1. Picture-in-Picture (PiP) - permissions, status, entering PiP, auto-enter on background.
/// 2. Alarms & Reminders - exact alarm permission status and direct App Info settings intent.
class SystemFeaturesService {
  SystemFeaturesService._();
  static final SystemFeaturesService instance = SystemFeaturesService._();

  static const MethodChannel _channel =
      MethodChannel('io.vyayama.fitbuddy/system_features');

  final ValueNotifier<bool> pipModeNotifier = ValueNotifier<bool>(false);
  bool _initialized = false;

  bool get isAndroid {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Initializes listeners for native PiP state transitions.
  void initialize() {
    if (_initialized || !isAndroid) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final inPip = call.arguments as bool? ?? false;
        debugPrint('[SystemFeaturesService] onPipModeChanged: $inPip');
        pipModeNotifier.value = inPip;
      }
    });
  }

  /// Whether the current device supports Picture-in-Picture (Android 8.0+).
  Future<bool> isPipSupported() async {
    if (!isAndroid) return false;
    initialize();
    try {
      final supported = await _channel.invokeMethod<bool>('isPipSupported');
      return supported ?? false;
    } catch (e) {
      debugPrint('[SystemFeaturesService] isPipSupported error: $e');
      return false;
    }
  }

  /// Whether Picture-in-Picture permission is allowed in system App Info.
  Future<bool> isPipAllowed() async {
    if (!isAndroid) return false;
    initialize();
    try {
      final allowed = await _channel.invokeMethod<bool>('isPipAllowed');
      return allowed ?? true;
    } catch (e) {
      debugPrint('[SystemFeaturesService] isPipAllowed error: $e');
      return true;
    }
  }

  /// Opens the system Settings -> App Info -> Picture-in-picture page.
  Future<void> openPipSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openPipSettings');
    } catch (e) {
      debugPrint('[SystemFeaturesService] openPipSettings error: $e');
    }
  }

  /// Enters Picture-in-Picture mode immediately.
  /// Returns true if the device successfully entered PiP mode.
  Future<bool> enterPip({int aspectRatioX = 16, int aspectRatioY = 9}) async {
    if (!isAndroid) return false;
    initialize();
    try {
      final entered = await _channel.invokeMethod<bool>('enterPip', {
        'aspectRatioX': aspectRatioX,
        'aspectRatioY': aspectRatioY,
      });
      if (entered == true) {
        pipModeNotifier.value = true;
      }
      return entered ?? false;
    } catch (e) {
      debugPrint('[SystemFeaturesService] enterPip error: $e');
      return false;
    }
  }

  /// Sets whether the app should automatically enter Picture-in-Picture when backgrounded
  /// (e.g. during an active workout session).
  Future<void> setAutoEnterPip(
    bool enabled, {
    int aspectRatioX = 16,
    int aspectRatioY = 9,
  }) async {
    if (!isAndroid) return;
    initialize();
    try {
      await _channel.invokeMethod('setAutoEnterPip', {
        'enabled': enabled,
        'aspectRatioX': aspectRatioX,
        'aspectRatioY': aspectRatioY,
      });
    } catch (e) {
      debugPrint('[SystemFeaturesService] setAutoEnterPip error: $e');
    }
  }

  /// Checks if the app is allowed to schedule exact alarms (SCHEDULE_EXACT_ALARM on Android 12+).
  Future<bool> canScheduleExactAlarms() async {
    if (!isAndroid) return true;
    try {
      final allowed =
          await _channel.invokeMethod<bool>('canScheduleExactAlarms');
      return allowed ?? true;
    } catch (e) {
      debugPrint('[SystemFeaturesService] canScheduleExactAlarms error: $e');
      return true;
    }
  }

  /// Opens the direct "Alarms & reminders" system App Info settings screen.
  Future<void> openAlarmsAndRemindersSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openAlarmsAndRemindersSettings');
    } catch (e) {
      debugPrint('[SystemFeaturesService] openAlarmsAndRemindersSettings error: $e');
    }
  }
}
