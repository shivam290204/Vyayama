import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';

final soundEnabledProvider = StateNotifierProvider<SoundEnabledNotifier, bool>((ref) {
  return SoundEnabledNotifier();
});

class SoundEnabledNotifier extends StateNotifier<bool> {
  SoundEnabledNotifier() : super(true) {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('sound_effects_enabled') ?? true;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !state;
    await prefs.setBool('sound_effects_enabled', next);
    state = next;
  }
}

final mascotSoundServiceProvider = Provider<MascotSoundService>((ref) {
  return MascotSoundService(ref);
});

class MascotSoundService {
  MascotSoundService(this.ref) {
    _initAudio();
  }

  final Ref ref;
  final AudioPlayer _player = AudioPlayer();

  Future<void> _initAudio() async {
    await _player.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        audioMode: AndroidAudioMode.normal,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
    ));
  }

  Future<void> playForMoodChange(MascotMood newMood) async {
    if (!ref.read(soundEnabledProvider)) return;

    if (newMood == MascotMood.happy || newMood == MascotMood.proud || newMood == MascotMood.celebrating) {
      try {
        await _player.play(AssetSource('audio/happy.mp3'));
        HapticFeedback.lightImpact();
      } catch (e) {
        // fail silently
      }
    }
  }
}
