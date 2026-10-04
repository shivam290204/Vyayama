import 'package:flutter/material.dart';

/// Wraps a list of slivers or children in an implicit entrance animation.
/// When first built, the children fade and slide up sequentially.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 75),
    this.duration = const Duration(milliseconds: 400),
  });

  final List<Widget> children;
  final Duration delay;
  final Duration stagger;
  final Duration duration;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  final Map<int, bool> _visible = {};

  @override
  void initState() {
    super.initState();
    _triggerAnimations();
  }

  Future<void> _triggerAnimations() async {
    await Future.delayed(widget.delay);
    for (var i = 0; i < widget.children.length; i++) {
      if (!mounted) return;
      setState(() => _visible[i] = true);
      await Future.delayed(widget.stagger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.children.length, (i) {
        final child = widget.children[i];
        if (reduceMotion) return child;

        final isVisible = _visible[i] ?? false;

        return AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: isVisible ? Offset.zero : const Offset(0.0, 0.15),
            duration: widget.duration,
            curve: Curves.easeOutCubic,
            child: child,
          ),
        );
      }),
    );
  }
}
