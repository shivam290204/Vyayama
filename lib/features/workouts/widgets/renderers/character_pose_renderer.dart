import 'package:flutter/material.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/exercise_renderer.dart';

/// Renders a high-fidelity 3D character pose with gentle breathing/float dynamics
/// and a sleek glassmorphic badge.
class CharacterPoseRenderer implements ExerciseRenderer {
  const CharacterPoseRenderer({this.label});

  final String? label;

  @override
  bool canHandle(String? asset, List<String> poses) {
    if (asset == null) return false;
    final isRaster = asset.endsWith('.png') ||
        asset.endsWith('.jpg') ||
        asset.endsWith('.webp');
    final isKnownPath = asset.contains('assets/exercises/') ||
        asset.contains('assets/images/mascot/') ||
        asset.contains('assets/mascot/');
    return isRaster && isKnownPath;
  }

  @override
  Widget build({
    required BuildContext context,
    required String? asset,
    required List<String> poses,
    required double height,
  }) {
    if (asset == null || asset.isEmpty) return const SizedBox.shrink();

    return _CharacterPoseView(
      asset: asset,
      label: label,
      height: height,
    );
  }
}

class _CharacterPoseView extends StatefulWidget {
  const _CharacterPoseView({
    required this.asset,
    this.label,
    required this.height,
  });

  final String asset;
  final String? label;
  final double height;

  @override
  State<_CharacterPoseView> createState() => _CharacterPoseViewState();
}

class _CharacterPoseViewState extends State<_CharacterPoseView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _breatheAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        // Subtle ambient radial glow
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.9,
              colors: [
                AppPalette.limeGreen.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // 3D Character with gentle animation
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: AnimatedBuilder(
              animation: _breatheAnimation,
              builder: (context, child) {
                final scale = reduceMotion ? 1.0 : _breatheAnimation.value;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  widget.asset,
                  fit: BoxFit.contain,
                  height: widget.height * 0.88,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.fitness_center_rounded,
                      size: 56,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Flat athletic character form badge
        Positioned(
          bottom: 10,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.charcoalGreen.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppPalette.limeGreen.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.accessibility_new_rounded,
                  size: 13,
                  color: AppPalette.limeGreen,
                ),
                SizedBox(width: 5),
                Text(
                  'Form Guide',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
