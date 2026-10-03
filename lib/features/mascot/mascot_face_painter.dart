import 'dart:math' as math;

import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:flutter/material.dart';

/// Draws eyes, brows, mouth and small extras (tears, steam, Zzz) for the
/// drawn mascot.
class MascotFace {
  const MascotFace._();

  static Color _a(Color c, double o) => c.withAlpha((o * 255).round());

  /// Paints the face of [mood] around body centre [c], for a square of
  /// side [s]. [t] is the looping animation value from 0 to 1.
  static void paint(
    Canvas canvas, {
    required double s,
    required Offset c,
    required MascotMood mood,
    required ColorScheme scheme,
    required double t,
  }) {
    final ink = scheme.onPrimaryContainer;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.022;
    final fill = Paint()..color = ink;
    final white = Paint()..color = scheme.surface;
    final l = c + Offset(-0.13 * s, -0.05 * s);
    final r = c + Offset(0.13 * s, -0.05 * s);
    final mouth = c + Offset(0, 0.1 * s);
    final wave = math.sin(t * 2 * math.pi);

    switch (mood) {
      case MascotMood.neutral:
        _eyes(canvas, s, l, r, Offset.zero, white, fill, 0.075);
        _brows(canvas, s, l, r, line, -0.1, -0.1);
        canvas.drawLine(
          mouth + Offset(-0.04 * s, 0),
          mouth + Offset(0.04 * s, 0),
          line,
        );
      case MascotMood.happy:
        _eyes(canvas, s, l, r, Offset(0, -0.004 * s), white, fill, 0.075);
        _brows(canvas, s, l, r, line, -0.12, -0.12);
        _curve(canvas, mouth, 0.07 * s, 0.035 * s, line);
        _blush(canvas, s, c, _a(scheme.tertiary, 0.3));
      case MascotMood.proud:
        _happyEyes(canvas, s, l, r, line);
        _brows(canvas, s, l, r, line, -0.13, -0.135);
        _curve(canvas, mouth, 0.09 * s, 0.05 * s, line);
        _blush(canvas, s, c, _a(scheme.tertiary, 0.4));
      case MascotMood.sad:
        _eyes(canvas, s, l, r, Offset(0, 0.02 * s), white, fill, 0.075);
        _brows(canvas, s, l, r, line, -0.085, -0.135);
        _curve(canvas, mouth + Offset(0, 0.03 * s), 0.05 * s, -0.03 * s, line);
        canvas.drawCircle(
          l + Offset(-0.03 * s, (0.07 + 0.06 * t) * s),
          s * 0.018,
          Paint()..color = _a(scheme.secondary, 0.85),
        );
      case MascotMood.angry:
        _eyes(canvas, s, l, r, Offset.zero, white, fill, 0.062);
        final thick = Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.034;
        _brows(canvas, s, l, r, thick, -0.125, -0.07);
        _curve(canvas, mouth + Offset(0, 0.03 * s), 0.045 * s, -0.02 * s, line);
        _blush(canvas, s, c, _a(scheme.error, 0.35));
        for (final sign in [-1.0, 1.0]) {
          canvas.drawCircle(
            c + Offset(sign * 0.2 * s, (-0.36 - 0.02 * wave) * s),
            s * (0.03 + 0.008 * wave),
            Paint()..color = _a(scheme.error, 0.3),
          );
        }
      case MascotMood.sleepy:
        for (final e in [l, r]) {
          final p = Path()
            ..moveTo(e.dx - 0.055 * s, e.dy)
            ..quadraticBezierTo(e.dx, e.dy + 0.06 * s, e.dx + 0.055 * s, e.dy);
          canvas.drawPath(p, line);
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: mouth + Offset(0, 0.01 * s),
            width: 0.035 * s,
            height: 0.03 * s,
          ),
          line,
        );
        _zzz(canvas, s, c, scheme, t);
      case MascotMood.celebrating:
        _happyEyes(canvas, s, l, r, line);
        _brows(canvas, s, l, r, line, -0.13, -0.135);
        final open = Path()
          ..moveTo(mouth.dx - 0.075 * s, mouth.dy - 0.01 * s)
          ..quadraticBezierTo(
            mouth.dx,
            mouth.dy + 0.2 * s,
            mouth.dx + 0.075 * s,
            mouth.dy - 0.01 * s,
          )
          ..close();
        canvas.drawPath(open, fill);
        canvas.drawOval(
          Rect.fromCenter(
            center: mouth + Offset(0, 0.06 * s),
            width: 0.06 * s,
            height: 0.04 * s,
          ),
          Paint()..color = scheme.tertiary,
        );
        _blush(canvas, s, c, _a(scheme.tertiary, 0.4));
      case MascotMood.worried:
        _eyes(canvas, s, l, r, Offset(0.022 * s * wave, -0.004 * s), white,
            fill, 0.085);
        _brows(canvas, s, l, r, line, -0.09, -0.13);
        final wavy = Path()
          ..moveTo(mouth.dx - 0.05 * s, mouth.dy)
          ..quadraticBezierTo(
            mouth.dx - 0.025 * s,
            mouth.dy - 0.02 * s,
            mouth.dx,
            mouth.dy,
          )
          ..quadraticBezierTo(
            mouth.dx + 0.025 * s,
            mouth.dy + 0.02 * s,
            mouth.dx + 0.05 * s,
            mouth.dy,
          );
        canvas.drawPath(wavy, line);
        canvas.drawCircle(
          r + Offset(0.1 * s, (-0.03 + 0.05 * t) * s),
          s * 0.02,
          Paint()..color = _a(scheme.secondary, 0.85),
        );
    }
  }

  static void _eyes(
    Canvas canvas,
    double s,
    Offset l,
    Offset r,
    Offset pupil,
    Paint white,
    Paint fill,
    double radius,
  ) {
    final rad = radius * s;
    for (final e in [l, r]) {
      canvas.drawCircle(e, rad, white);
      canvas.drawCircle(e + pupil, rad * 0.52, fill);
      canvas.drawCircle(
        e + pupil + Offset(-rad * 0.15, -rad * 0.18),
        rad * 0.14,
        white,
      );
    }
  }

  static void _happyEyes(
    Canvas canvas,
    double s,
    Offset l,
    Offset r,
    Paint line,
  ) {
    for (final e in [l, r]) {
      final p = Path()
        ..moveTo(e.dx - 0.055 * s, e.dy + 0.02 * s)
        ..quadraticBezierTo(e.dx, e.dy - 0.07 * s, e.dx + 0.055 * s, e.dy + 0.02 * s);
      canvas.drawPath(p, line);
    }
  }

  /// Brows: [outerY] and [innerY] are fractions of [s] above the eye centre
  /// (negative is up). Inner means the end closest to the nose.
  static void _brows(
    Canvas canvas,
    double s,
    Offset l,
    Offset r,
    Paint paint,
    double outerY,
    double innerY,
  ) {
    canvas.drawLine(
      l + Offset(-0.06 * s, outerY * s),
      l + Offset(0.06 * s, innerY * s),
      paint,
    );
    canvas.drawLine(
      r + Offset(0.06 * s, outerY * s),
      r + Offset(-0.06 * s, innerY * s),
      paint,
    );
  }

  /// Mouth curve. Positive [bend] is a smile, negative a frown.
  static void _curve(
    Canvas canvas,
    Offset center,
    double halfWidth,
    double bend,
    Paint paint,
  ) {
    final p = Path()
      ..moveTo(center.dx - halfWidth, center.dy)
      ..quadraticBezierTo(
        center.dx,
        center.dy + bend * 2,
        center.dx + halfWidth,
        center.dy,
      );
    canvas.drawPath(p, paint);
  }

  static void _blush(Canvas canvas, double s, Offset c, Color color) {
    final paint = Paint()..color = color;
    for (final dx in [-0.21, 0.21]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(dx * s, 0.06 * s),
          width: 0.07 * s,
          height: 0.04 * s,
        ),
        paint,
      );
    }
  }

  static void _zzz(
    Canvas canvas,
    double s,
    Offset c,
    ColorScheme scheme,
    double t,
  ) {
    for (var i = 0; i < 2; i++) {
      final phase = (t + i * 0.5) % 1.0;
      final tp = TextPainter(
        text: TextSpan(
          text: 'z',
          style: TextStyle(
            fontSize: s * (0.09 + 0.04 * i),
            fontWeight: FontWeight.w800,
            color: _a(scheme.onSurfaceVariant, 1 - phase),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        c +
            Offset(
              (0.2 + 0.05 * i) * s + 0.03 * s * phase,
              (-0.3 - 0.07 * i) * s - 0.05 * s * phase,
            ),
      );
    }
  }
}
