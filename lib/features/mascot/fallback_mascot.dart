import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/mascot_painter.dart';
import 'package:flutter/material.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';

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
    duration: const Duration(milliseconds: 500), // Base bounce duration
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

  MascotConfig _getConfigForMood(MascotMood mood, ColorScheme scheme) {
    final accent = AppPalette.accent;

    switch (mood) {
      case MascotMood.neutral:
        return MascotConfig(bodyColor: accent, curvature: 0.15, wobble: 0, scaleY: 1.0, eyeOpenness: 1.0, eyebrowsAmount: 0);
      case MascotMood.happy:
        return MascotConfig(bodyColor: accent, curvature: 1.0, wobble: 0, scaleY: 1.0, eyeOpenness: 1.0, eyebrowsAmount: 0);
      case MascotMood.proud:
        return MascotConfig(bodyColor: accent, curvature: 0.8, wobble: 0, scaleY: 1.0, eyeOpenness: 0.5, eyebrowsAmount: 0);
      case MascotMood.celebrating:
        return MascotConfig(bodyColor: accent, curvature: 1.2, wobble: 0, scaleY: 1.0, eyeOpenness: 1.0, eyebrowsAmount: 0);
      case MascotMood.sad:
        // Desaturate slightly by lerping with grey/surface
        return MascotConfig(bodyColor: Color.lerp(accent, scheme.surfaceContainerHighest, 0.4) ?? accent, curvature: -0.9, wobble: 0, scaleY: 0.95, eyeOpenness: 1.0, eyebrowsAmount: 0);
      case MascotMood.angry:
        return MascotConfig(bodyColor: AppPalette.error, curvature: -0.4, wobble: 0, scaleY: 1.0, eyeOpenness: 1.0, eyebrowsAmount: 1.0);
      case MascotMood.worried:
        return MascotConfig(bodyColor: accent, curvature: -0.3, wobble: 0.6, scaleY: 1.0, eyeOpenness: 1.0, eyebrowsAmount: 0);
      case MascotMood.sleepy:
        return MascotConfig(bodyColor: Color.lerp(accent, Colors.black, 0.2) ?? accent, curvature: 0.1, wobble: 0, scaleY: 1.0, eyeOpenness: 0.1, eyebrowsAmount: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final targetConfig = _getConfigForMood(widget.mood, scheme);

    return TweenAnimationBuilder<MascotConfig>(
      tween: _MascotConfigTween(end: targetConfig),
      duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
      builder: (context, config, _) {
        return AnimatedBuilder(
          animation: Listenable.merge([_loopController, _bounceController]),
          builder: (context, _) => CustomPaint(
            size: Size.square(widget.size),
            painter: MascotPainter(
              config: config,
              loopTime: _loopController.value,
              bounceTime: _bounceController.value,
              bounceCount: _bounceCount,
              tearColor: AppPalette.primary,
              onBodyColor: AppPalette.darkBackground, // Original dark text for eyes/mouth on accent/red
            ),
          ),
        );
      },
    );
  }
}

class _MascotConfigTween extends Tween<MascotConfig> {
  _MascotConfigTween({required super.end});
  
  @override
  MascotConfig lerp(double t) {
    if (begin == null) return end!;
    return MascotConfig.lerp(begin!, end!, t);
  }
}
