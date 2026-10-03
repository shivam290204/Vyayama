import 'package:flutter/material.dart';

/// A rounded speech bubble with a small tail pointing down at the mascot.
///
/// Changes are announced to screen readers (live region) and fade in
/// unless reduced motion is on.
class SpeechBubble extends StatelessWidget {
  /// Creates the bubble.
  const SpeechBubble({super.key, required this.message});

  /// Text to show.
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedSwitcher(
              duration:
                  reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
              child: Text(
                message,
                key: ValueKey<String>(message),
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: scheme.onSurface),
              ),
            ),
          ),
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size(24, 12),
              painter: _TailPainter(scheme.surfaceContainerHighest),
            ),
          ),
        ],
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}
