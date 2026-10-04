import 'package:flutter/material.dart';

/// A card that shrinks slightly when pressed down, creating a tactile bouncing
/// effect. Used to make tap targets feel more interactive and premium.
class BouncingCard extends StatefulWidget {
  const BouncingCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = EdgeInsets.zero,
    this.color,
    this.shape,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final ShapeBorder? shape;

  @override
  State<BouncingCard> createState() => _BouncingCardState();
}

class _BouncingCardState extends State<BouncingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget card = Card(
      margin: widget.margin,
      clipBehavior: Clip.antiAlias,
      color: widget.color,
      shape: widget.shape,
      child: InkWell(
        onTap: widget.onTap,
        onTapDown: reduceMotion ? null : _onTapDown,
        onTapUp: reduceMotion ? null : _onTapUp,
        onTapCancel: reduceMotion ? null : _onTapCancel,
        child: widget.child,
      ),
    );

    if (reduceMotion) return card;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: card,
    );
  }
}
