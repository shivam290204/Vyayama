import 'package:flutter/material.dart';

/// A section header with an animated accent bar that slides in from the left,
/// and title/subtitle that fade in. Used to delineate content sections with
/// visual flair.
class AnimatedSectionHeader extends StatefulWidget {
  const AnimatedSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.delay = Duration.zero,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Duration delay;

  @override
  State<AnimatedSectionHeader> createState() => _AnimatedSectionHeaderState();
}

class _AnimatedSectionHeaderState extends State<AnimatedSectionHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _barWidth;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _barWidth = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _startAfterDelay();
  }

  Future<void> _startAfterDelay() async {
    await Future.delayed(widget.delay);
    if (mounted) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (reduceMotion) {
      return _buildContent(scheme, text, 1.0, 1.0);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          _buildContent(scheme, text, _barWidth.value, _textOpacity.value),
    );
  }

  Widget _buildContent(
    ColorScheme scheme,
    TextTheme text,
    double barProgress,
    double textAlpha,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar
          Container(
            width: 40 * barProgress,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Title row
          Opacity(
            opacity: textAlpha,
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
          // Subtitle
          if (widget.subtitle != null)
            Opacity(
              opacity: textAlpha,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.subtitle!,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
