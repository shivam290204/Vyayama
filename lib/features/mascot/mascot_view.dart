import 'package:fitbuddy/features/mascot/fallback_mascot.dart';
import 'package:fitbuddy/features/mascot/mascot_constants.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/rive_mascot.dart';
import 'package:fitbuddy/features/mascot/mascot_sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

/// Checks once whether the Rive file is bundled.
abstract final class RiveAvailability {
  static Future<bool>? _result;

  /// True when `assets/rive/mascot.riv` can be loaded. Cached after the
  /// first call.
  static Future<bool> check() => _result ??= rootBundle
      .loadString('AssetManifest.json')
      .then((json) => (jsonDecode(json) as Map).containsKey(MascotAssets.rivePath))
      .catchError((_) => false);
}

/// The Vyayama mascot.
///
/// Uses the Rive animation when `assets/rive/mascot.riv` exists, otherwise
/// an original drawn character.
class MascotView extends ConsumerStatefulWidget {
  const MascotView({super.key, required this.mood, this.size = 200});

  final MascotMood mood;
  final double size;

  @override
  ConsumerState<MascotView> createState() => _MascotViewState();
}

class _MascotViewState extends ConsumerState<MascotView> {
  @override
  void didUpdateWidget(covariant MascotView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      ref.read(mascotSoundServiceProvider).playForMoodChange(widget.mood);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vyayama mascot, feeling ${widget.mood.label}',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: widget.size,
          child: FutureBuilder<bool>(
            future: RiveAvailability.check(),
            builder: (context, snapshot) {
              if (snapshot.data == true) return RiveMascot(mood: widget.mood);
              return FallbackMascot(mood: widget.mood, size: widget.size);
            },
          ),
        ),
      ),
    );
  }
}
