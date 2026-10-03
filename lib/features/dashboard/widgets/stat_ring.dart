import 'dart:math' as math;

import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// A circular progress ring with an icon, the value and a label below.
///
/// Screen readers hear the label, value, target and percentage.
class StatRing extends StatelessWidget {
  /// Creates the ring.
  const StatRing({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.target,
    required this.unit,
    required this.color,
    this.size = 104,
  });

  /// Name, for example "Steps".
  final String label;

  /// Icon inside the ring.
  final IconData icon;

  /// Current value.
  final int value;

  /// Daily target.
  final int target;

  /// Unit, for example "steps".
  final String unit;

  /// Progress colour.
  final Color color;

  /// Ring diameter.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final progress = target <= 0 ? 0.0 : value / target;
    final done = progress >= 1;
    final percent = (progress * 100).round();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: label,
      value: '${formatInt(value)} of ${formatInt(target)} $unit, '
          '$percent percent',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(
              begin: 0,
              end: progress.clamp(0.0, 1.0).toDouble(),
            ),
            duration:
                reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animated, child) => SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: animated,
                  color: color,
                  track: scheme.surfaceContainerHighest,
                  stroke: size * 0.12,
                ),
                child: child,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    done ? Icons.check_circle : icon,
                    size: size * 0.22,
                    color: color,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatInt(value), style: text.titleSmall),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: text.labelLarge),
          Text(
            'of ${formatInt(target)} $unit',
            style: text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0.001) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
