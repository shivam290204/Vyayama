import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio asset paths for the two alarm types.
abstract final class AppSounds {
  /// Wake-up alarm sound (plays when the morning alarm fires).
  static const String wakeUpAlarm = 'audio/wakeupAlarm.wav';

  /// Medicine / warning reminder sound.
  static const String medicineWarning = 'audio/warningalarm.mp3';
}

/// Singleton service that plays the two bundled alarm sounds.
///
/// Use [AppSoundService.instance] to play a sound anywhere, or inject via
/// [appSoundServiceProvider] inside Riverpod widgets.
class AppSoundService {
  AppSoundService._();
  static final AppSoundService instance = AppSoundService._();

  AudioPlayer? _player;
  bool _playing = false;

  /// Play the wake-up alarm sound. Loops until [stop] is called.
  Future<void> playWakeUpAlarm() => _play(AppSounds.wakeUpAlarm, loop: true);

  /// Play the medicine / warning reminder sound once.
  Future<void> playMedicineAlert() =>
      _play(AppSounds.medicineWarning, loop: false);

  /// Stop any currently playing alarm/alert.
  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('AppSoundService stop error: $e');
    }
  }

  Future<void> _play(String asset, {required bool loop}) async {
    await stop();
    _playing = true;
    _player ??= AudioPlayer();
    try {
      if (!kIsWeb) {
        try {
          await _player!.setAudioContext(
            AudioContext(
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
                options: const {AVAudioSessionOptions.duckOthers},
              ),
              android: AudioContextAndroid(
                isSpeakerphoneOn: true,
                audioMode: AndroidAudioMode.normal,
                contentType: AndroidContentType.music,
                usageType: AndroidUsageType.alarm,
              ),
            ),
          );
        } catch (_) {}
      }
      await _player!.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player!.play(AssetSource(asset));
    } catch (e) {
      debugPrint('AppSoundService play error: $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _playing = false;
  }
}

final appSoundServiceProvider = Provider<AppSoundService>((ref) {
  final service = AppSoundService.instance;
  ref.onDispose(service.stop);
  return service;
});
