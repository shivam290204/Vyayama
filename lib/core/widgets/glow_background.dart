import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// A modern, premium background with softly pulsing glowing orbs and a
/// glassmorphic blur overlay. Adapts to light/dark mode. The orbs drift
/// gently to feel alive.
class GlowBackground extends StatefulWidget {
  const GlowBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<GlowBackground> createState() => _GlowBackgroundState();
}

class _GlowBackgroundState extends State<GlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final size = MediaQuery.sizeOf(context);

    if (reduceMotion) {
      return _StaticBackground(scheme: scheme, isDark: isDark, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Gentle sine-based drift
        final dx1 = math.sin(t * 2 * math.pi) * 20;
        final dy1 = math.cos(t * 2 * math.pi) * 15;
        final dx2 = math.cos(t * 2 * math.pi + 1) * 25;
        final dy2 = math.sin(t * 2 * math.pi + 1) * 20;
        final dx3 = math.sin(t * 2 * math.pi + 2.5) * 18;
        final dy3 = math.cos(t * 2 * math.pi + 2.5) * 22;

        return Stack(
          children: [
            // Base background
            Container(color: scheme.surface),

            if (isDark) ...[
              // Orb 1: Primary (top-left area)
              Positioned(
                top: -80 + dy1,
                left: -80 + dx1,
                child: _GlowOrb(
                  diameter: 320,
                  color: scheme.primary.withValues(alpha: 0.16),
                ),
              ),

              // Orb 2: Secondary (bottom-right area)
              Positioned(
                bottom: 60 + dy2,
                right: -80 + dx2,
                child: _GlowOrb(
                  diameter: 380,
                  color: scheme.secondary.withValues(alpha: 0.14),
                ),
              ),

              // Orb 3: Tertiary blend (center-left)
              Positioned(
                top: size.height * 0.4 + dy3,
                left: -120 + dx3,
                child: _GlowOrb(
                  diameter: 350,
                  color: scheme.tertiary.withValues(alpha: 0.10),
                ),
              ),

              // Blur layer
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: const SizedBox.expand(),
                ),
              ),
            ],

            // Content
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}

class _StaticBackground extends StatelessWidget {
  const _StaticBackground({
    required this.scheme,
    required this.isDark,
    required this.child,
  });

  final ColorScheme scheme;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: scheme.surface),
        if (isDark) ...[
          Positioned(
            top: -80,
            left: -80,
            child: _GlowOrb(
              diameter: 320,
              color: scheme.primary.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -80,
            child: _GlowOrb(
              diameter: 380,
              color: scheme.secondary.withValues(alpha: 0.14),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox.expand(),
            ),
          ),
        ],
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
