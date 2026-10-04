import 'dart:ui';
import 'package:flutter/material.dart';

/// A modern, premium background with soft glowing orbs and a glassmorphic blur
/// over them. Adapts to light/dark mode.
class GlowBackground extends StatelessWidget {
  const GlowBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Soft, wide radial gradients that blend into the background.
    return Stack(
      children: [
        // Base background color
        Container(color: scheme.surface),
        
        // Top-left primary glow
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
        ),
        
        // Bottom-right secondary glow
        Positioned(
          bottom: 100,
          right: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondary.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
          ),
        ),

        // Center-left tertiary glow
        Positioned(
          top: MediaQuery.sizeOf(context).height * 0.4,
          left: -150,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: isDark ? 0.1 : 0.05),
            ),
          ),
        ),

        // Heavy blur layer (Glassmorphism)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),

        // The actual content on top
        Positioned.fill(child: child),
      ],
    );
  }
}
