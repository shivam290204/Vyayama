import 'package:fitbuddy/features/mascot/fallback_mascot.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/mascot_sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Vyayama mascot.
///
/// Displays the animated mascot character corresponding to the current [MascotMood].
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
          child: FallbackMascot(mood: widget.mood, size: widget.size),
        ),
      ),
    );
  }
}
