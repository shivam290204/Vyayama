import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_palette.dart';

/// Custom painter that draws three concentric circular progress rings.
/// Outer: Steps (Lime Green)
/// Middle: Active Minutes (Teal / Cyan)
/// Inner: Calories (Purple)
class ConcentricRingsPainter extends CustomPainter {
  const ConcentricRingsPainter({
    required this.stepProgress,
    required this.activeMinutesProgress,
    required this.calorieProgress,
    this.stepColor = AppPalette.activitySteps,
    this.activeMinutesColor = AppPalette.activityMinutes,
    this.calorieColor = AppPalette.activityCalories,
    this.trackOpacity = 0.18,
    this.ringWidth = 2.8,
    this.ringSpacing = 1.6,
  });

  /// Progress from 0.0 to 1.0 (clamped).
  final double stepProgress;
  final double activeMinutesProgress;
  final double calorieProgress;

  final Color stepColor;
  final Color activeMinutesColor;
  final Color calorieColor;
  final double trackOpacity;
  final double ringWidth;
  final double ringSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - (ringWidth / 2);

    if (maxRadius <= 0) return;

    final outerRadius = maxRadius;
    final middleRadius = outerRadius - ringWidth - ringSpacing;
    final innerRadius = middleRadius - ringWidth - ringSpacing;

    // Draw Outer: Steps
    if (outerRadius > 0) {
      _drawRing(
        canvas: canvas,
        center: center,
        radius: outerRadius,
        progress: stepProgress,
        color: stepColor,
      );
    }

    // Draw Middle: Active Minutes
    if (middleRadius > 0) {
      _drawRing(
        canvas: canvas,
        center: center,
        radius: middleRadius,
        progress: activeMinutesProgress,
        color: activeMinutesColor,
      );
    }

    // Draw Inner: Calories
    if (innerRadius > 0) {
      _drawRing(
        canvas: canvas,
        center: center,
        radius: innerRadius,
        progress: calorieProgress,
        color: calorieColor,
      );
    }
  }

  void _drawRing({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required double progress,
    required Color color,
  }) {
    final trackPaint = Paint()
      ..color = color.withValues(alpha: trackOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..isAntiAlias = true;

    // Background track (full 360 degree circle)
    canvas.drawCircle(center, radius, trackPaint);

    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      // Start from top (-pi / 2) and sweep clockwise
      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * clampedProgress;
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConcentricRingsPainter oldDelegate) {
    return oldDelegate.stepProgress != stepProgress ||
        oldDelegate.activeMinutesProgress != activeMinutesProgress ||
        oldDelegate.calorieProgress != calorieProgress ||
        oldDelegate.stepColor != stepColor ||
        oldDelegate.activeMinutesColor != activeMinutesColor ||
        oldDelegate.calorieColor != calorieColor ||
        oldDelegate.ringWidth != ringWidth ||
        oldDelegate.ringSpacing != ringSpacing ||
        oldDelegate.trackOpacity != trackOpacity;
  }
}
