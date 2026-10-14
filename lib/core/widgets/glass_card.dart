import 'package:flutter/material.dart';

/// A glassmorphic container with a subtle gradient border, translucent fill,
/// and an optional shimmer highlight. Designed for a premium feel.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.gradient,
    this.width = double.infinity,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Gradient? gradient;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final fillColor = isDark ? const Color(0xFF202820) : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF3B4D3B).withValues(alpha: 0.5)
        : const Color(0xFFE5E9E0);

    Widget card = Container(
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient != null ? null : fillColor,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: onTap != null
              ? InkWell(
                  onTap: onTap,
                  splashColor: scheme.primary.withValues(alpha: 0.1),
                  highlightColor: scheme.primary.withValues(alpha: 0.05),
                  child: Padding(padding: padding, child: child),
                )
              : Padding(padding: padding, child: child),
        ),
      ),
    );

    return card;
  }
}
