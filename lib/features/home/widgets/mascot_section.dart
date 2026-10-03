import 'package:fitbuddy/features/home/widgets/speech_bubble.dart';
import 'package:fitbuddy/features/mascot/mascot_view.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Large mascot with a speech bubble. Tap the mascot for another message.
class MascotSection extends ConsumerWidget {
  /// Creates the section.
  const MascotSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(moodProvider);
    final message = ref.watch(mascotMessageProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth * 0.6).clamp(140.0, 240.0).toDouble();
        return Column(
          children: [
            SpeechBubble(message: message),
            Semantics(
              button: true,
              hint: 'Tap for another message',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => ref.read(mascotVariantProvider.notifier).next(),
                child: MascotView(mood: mood, size: size),
              ),
            ),
          ],
        );
      },
    );
  }
}
