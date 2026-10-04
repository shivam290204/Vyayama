import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Draws a circular progress arc with a rounded cap over a faint track.
/// The arc starts at 12 o'clock and fills clockwise.
class ProgressRingPainter extends CustomPainter {
  ProgressRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  /// Progress fraction, 0.0 to 1.0 (clamped internally).
  final double progress;

  /// Colour of the filled arc.
  final Color ringColor;

  /// Colour of the background track.
  final Color trackColor;

  /// Width of the arc stroke.
  final double strokeWidth;

  static const double _startAngle = -math.pi / 2; // 12 o'clock

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (full circle, rounded ends).
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Arc.
    final clamped = progress.clamp(0.0, 1.0);
    if (clamped <= 0) return;

    final sweepAngle = 2 * math.pi * clamped;
    final arcPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, sweepAngle, false, arcPaint);
  }

  @override
  bool shouldRepaint(ProgressRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      ringColor != oldDelegate.ringColor ||
      trackColor != oldDelegate.trackColor ||
      strokeWidth != oldDelegate.strokeWidth;
}
