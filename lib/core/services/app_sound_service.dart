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
  StreamSubscription<void>? _completionSub;
  bool _playing = false;

  /// Notifies listeners when audio is playing or stopped.
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);

  /// Notifies listeners of the active asset path playing, or null when idle.
  final ValueNotifier<String?> currentPlayingSoundNotifier =
      ValueNotifier<String?>(null);

  /// Whether an audio sound is currently actively playing.
  bool get isPlaying => _playing;

  /// Play the wake-up alarm sound. Loops until [stop] is called.
  Future<void> playWakeUpAlarm() => _play(AppSounds.wakeUpAlarm, loop: true);

  /// Play the medicine / warning reminder sound once.
  Future<void> playMedicineAlert() =>
      _play(AppSounds.medicineWarning, loop: false);

  /// Stop any currently playing alarm/alert.
  Future<void> stop() async {
    _playing = false;
    isPlayingNotifier.value = false;
    currentPlayingSoundNotifier.value = null;
    await _completionSub?.cancel();
    _completionSub = null;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('AppSoundService stop error: $e');
    }
  }

  Future<void> _play(String asset, {required bool loop}) async {
    await stop();
    _playing = true;
    isPlayingNotifier.value = true;
    currentPlayingSoundNotifier.value = asset;
    _player ??= AudioPlayer();
    try {
      await _player!.setVolume(1.0);
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

      // Listen for non-looping audio completion
      await _completionSub?.cancel();
      _completionSub = _player!.onPlayerComplete.listen((_) {
        if (!loop) {
          _playing = false;
          isPlayingNotifier.value = false;
          currentPlayingSoundNotifier.value = null;
        }
      });

      await _player!.play(AssetSource(asset));
    } catch (e) {
      debugPrint('AppSoundService play error: $e');
      _playing = false;
      isPlayingNotifier.value = false;
      currentPlayingSoundNotifier.value = null;
    }
  }

  void dispose() {
    _completionSub?.cancel();
    _completionSub = null;
    _player?.dispose();
    _player = null;
    _playing = false;
    isPlayingNotifier.value = false;
    currentPlayingSoundNotifier.value = null;
  }
}

final appSoundServiceProvider = Provider<AppSoundService>((ref) {
  final service = AppSoundService.instance;
  ref.onDispose(service.stop);
  return service;
});
