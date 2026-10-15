import 'dart:math' as math;
import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:flutter/material.dart';

class FallbackMascot extends StatefulWidget {
  const FallbackMascot({super.key, required this.mood, required this.size});

  final MascotMood mood;
  final double size;

  @override
  State<FallbackMascot> createState() => _FallbackMascotState();
}

class _FallbackMascotState extends State<FallbackMascot>
    with TickerProviderStateMixin {
  late final AnimationController _loopController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  late final AnimationController _bounceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  double _bounceCount = 0;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _loopController.stop();
      _bounceController.stop();
    } else {
      if (!_loopController.isAnimating) _loopController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant FallbackMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood && !_reduceMotion) {
      _triggerBounce(widget.mood);
    }
  }

  void _triggerBounce(MascotMood mood) {
    if (mood == MascotMood.happy) {
      _bounceCount = 2;
      _bounceController.duration = const Duration(milliseconds: 1000);
      _bounceController.forward(from: 0);
    } else if (mood == MascotMood.proud) {
      _bounceCount = 1;
      _bounceController.duration = const Duration(milliseconds: 800);
      _bounceController.forward(from: 0);
    } else if (mood == MascotMood.celebrating) {
      _bounceCount = 3;
      _bounceController.duration = const Duration(milliseconds: 1500);
      _bounceController.forward(from: 0);
    } else {
      _bounceCount = 0;
      _bounceController.stop();
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  String _getAssetForMood(MascotMood mood) {
    switch (mood) {
      case MascotMood.angry:
        return 'assets/images/mascot/anger.png';
      case MascotMood.sad:
        return 'assets/images/mascot/Sad_Drooped_Head.png';
      case MascotMood.worried:
        return 'assets/images/mascot/scratch_head.png';
      case MascotMood.sleepy:
        return 'assets/images/mascot/meditation.png';
      case MascotMood.proud:
        return 'assets/images/mascot/flex_proud.png';
      case MascotMood.celebrating:
        return 'assets/images/mascot/Fire_Determined.png';
      case MascotMood.happy:
        return 'assets/images/mascot/happy.png';
      case MascotMood.neutral:
        return 'assets/images/mascot/standing_hero.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _getAssetForMood(widget.mood);

    return AnimatedBuilder(
      animation: Listenable.merge([_loopController, _bounceController]),
      builder: (context, child) {
        double yOffset = 0.0;
        if (_bounceController.isAnimating && _bounceCount > 0) {
          final t = _bounceController.value * _bounceCount * math.pi;
          yOffset = -math.sin(t).abs() * (widget.size * 0.1);
        } else if (_loopController.isAnimating) {
          yOffset = -math.sin(_loopController.value * math.pi * 2) *
              (widget.size * 0.02);
        }

        return Transform.translate(
          offset: Offset(0, yOffset),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          assetPath,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          key: ValueKey(assetPath),
        ),
      ),
    );
  }
}
