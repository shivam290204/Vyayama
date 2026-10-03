import 'dart:math' as math;
import 'package:flutter/material.dart';

class MascotConfig {
  final Color bodyColor;
  final double curvature;
  final double wobble;
  final double scaleY;
  final double eyeOpenness;
  final double eyebrowsAmount;
  
  MascotConfig({
    required this.bodyColor,
    required this.curvature,
    required this.wobble,
    required this.scaleY,
    required this.eyeOpenness,
    required this.eyebrowsAmount,
  });

  static MascotConfig lerp(MascotConfig a, MascotConfig b, double t) {
    return MascotConfig(
      bodyColor: Color.lerp(a.bodyColor, b.bodyColor, t)!,
      curvature: (a.curvature + (b.curvature - a.curvature) * t),
      wobble: (a.wobble + (b.wobble - a.wobble) * t),
      scaleY: (a.scaleY + (b.scaleY - a.scaleY) * t),
      eyeOpenness: (a.eyeOpenness + (b.eyeOpenness - a.eyeOpenness) * t),
      eyebrowsAmount: (a.eyebrowsAmount + (b.eyebrowsAmount - a.eyebrowsAmount) * t),
    );
  }
}

class MascotPainter extends CustomPainter {
  final MascotConfig config;
  final double loopTime; // 0 to 1 continuously looping every 2s
  final double bounceTime; // 0 to 1 for current bounce (if any)
  final double bounceCount; // How many bounces left or currently doing
  final Color tearColor;
  final Color onBodyColor;

  MascotPainter({
    required this.config,
    required this.loopTime,
    required this.bounceTime,
    required this.bounceCount,
    required this.tearColor,
    required this.onBodyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final s = size.shortestSide;

    canvas.save();

    // Shake
    double dx = 0;
    if (config.eyebrowsAmount > 0) { // Angry shake
      dx = math.sin(loopTime * math.pi * 20) * 0.015 * s * config.eyebrowsAmount;
    }
    
    // Idle breathing
    double dy = math.sin(loopTime * math.pi * 2) * 0.015 * s * (1 - config.eyebrowsAmount) * (1 - bounceCount.clamp(0, 1));
    
    // Bouncing
    if (bounceCount > 0 && bounceTime > 0) {
      // A simple sine wave for the jump arc
      // bounceTime goes from 0 to 1 for the entire bounce sequence
      // We want to bounce 'bounceCount' times.
      final totalBounces = math.max(1, bounceCount.round());
      final currentPhase = bounceTime * totalBounces;
      if (currentPhase <= totalBounces) {
        final bounceArc = math.sin(currentPhase * math.pi);
        if (bounceArc > 0) {
          dy -= bounceArc * 0.15 * s; // jump height
        }
      }
    }

    canvas.translate(center.dx + dx, center.dy + dy);
    
    // Base scale and droop/squash
    double finalScaleY = config.scaleY;
    if (bounceCount > 0 && bounceTime > 0) {
      final totalBounces = math.max(1, bounceCount.round());
      final currentPhase = bounceTime * totalBounces;
      if (currentPhase <= totalBounces) {
        // Squash when hitting the ground
        final jump = math.sin(currentPhase * math.pi);
        if (jump < 0.1 && jump >= 0) { // near the ground
          finalScaleY *= 1.0 - (0.1 - jump);
        }
      }
    }
    
    canvas.scale(1.0, finalScaleY);

    // Body
    final bodyPaint = Paint()..color = config.bodyColor;
    canvas.drawCircle(Offset.zero, s * 0.4, bodyPaint);

    // Eyes
    final eyePaint = Paint()
      ..color = onBodyColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.05
      ..style = config.eyeOpenness < 0.3 ? PaintingStyle.stroke : PaintingStyle.fill;
    

    
    final leftEye = Offset(-s * 0.15, -s * 0.05);
    final rightEye = Offset(s * 0.15, -s * 0.05);

    if (config.eyeOpenness < 0.3) {
      // Short lines for sleepy
      canvas.drawLine(leftEye - Offset(s*0.03, 0), leftEye + Offset(s*0.03, 0), eyePaint);
      canvas.drawLine(rightEye - Offset(s*0.03, 0), rightEye + Offset(s*0.03, 0), eyePaint);
    } else {
      // Squinting logic: just scale the eye vertically
      canvas.save();
      canvas.translate(leftEye.dx, leftEye.dy);
      canvas.scale(1.0, config.eyeOpenness.clamp(0.2, 1.0));
      canvas.drawCircle(Offset.zero, s * 0.04, eyePaint);
      canvas.restore();
      
      canvas.save();
      canvas.translate(rightEye.dx, rightEye.dy);
      canvas.scale(1.0, config.eyeOpenness.clamp(0.2, 1.0));
      canvas.drawCircle(Offset.zero, s * 0.04, eyePaint);
      canvas.restore();
    }

    // Tear (for sad)
    if (config.scaleY < 0.98 && config.curvature < -0.5) { // sad heuristic
      // Loop time 0 to 1 every 2s
      if (loopTime < 0.5) {
        final tearProgress = loopTime * 2; // 0 to 1
        final tearY = leftEye.dy + s * 0.05 + (tearProgress * s * 0.15);
        final tearAlpha = ((1.0 - tearProgress) * 255).toInt().clamp(0, 255);
        
        final tp = Paint()..color = tearColor.withAlpha(tearAlpha);
        // Draw a simple water drop
        final tearCenter = Offset(leftEye.dx, tearY);
        final tearR = s * 0.02 * math.min(tearProgress * 3, 1.0);
        
        if (tearR > 0) {
           final p = Path()
            ..moveTo(tearCenter.dx, tearCenter.dy - tearR * 1.5)
            ..quadraticBezierTo(tearCenter.dx + tearR, tearCenter.dy + tearR * 0.5, tearCenter.dx, tearCenter.dy + tearR)
            ..quadraticBezierTo(tearCenter.dx - tearR, tearCenter.dy + tearR * 0.5, tearCenter.dx, tearCenter.dy - tearR * 1.5);
           canvas.drawPath(p, tp);
        }
      }
    }

    // Mouth
    final mouthPaint = Paint()
      ..color = onBodyColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.025;
    
    _drawFlexLine(
      canvas, mouthPaint, 
      Offset(0, s * 0.1), // center
      config.curvature, // curvature
      0.0, // tilt
      config.wobble * (math.sin(loopTime * math.pi * 8)), // wobble
      s * 0.1 // length
    );

    // Eyebrows
    if (config.eyebrowsAmount > 0) {
      final browPaint = Paint()
        ..color = onBodyColor.withAlpha((config.eyebrowsAmount * 255).toInt())
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.02;
      
      // Left brow, angled down and in
      _drawFlexLine(
        canvas, browPaint,
        Offset(-s * 0.15, -s * 0.15),
        -0.2, // slight curve
        0.3 * config.eyebrowsAmount, // tilt inwards
        0, 
        s * 0.08
      );
      // Right brow, angled down and in
      _drawFlexLine(
        canvas, browPaint,
        Offset(s * 0.15, -s * 0.15),
        -0.2,
        -0.3 * config.eyebrowsAmount, 
        0,
        s * 0.08
      );
    }

    canvas.restore();
  }

  void _drawFlexLine(
    Canvas canvas, 
    Paint paint, 
    Offset center, 
    double curvature, 
    double tilt, 
    double wobble, 
    double length
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);
    
    // Bezier curve
    // Start: (-length, 0), End: (length, 0)
    // Control: (0, curvature * length)
    // Wobble adds a vertical offset to the ends
    final start = Offset(-length, wobble * length);
    final end = Offset(length, -wobble * length);
    final ctrl = Offset(0, curvature * length);
    
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
      
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MascotPainter old) => true;
}
