import 'package:flutter/material.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/lottie_renderer.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/svg_pose_renderer.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/fallback_renderer.dart';

/// Factory widget for an exercise demo. Shows a calm placeholder when the
/// asset is missing or fails to load.
class ExerciseAnimation extends StatelessWidget {
  const ExerciseAnimation({
    super.key,
    required this.asset,
    required this.label,
    this.poses = const [],
    this.height = 220,
  });

  final String? asset;
  final List<String> poses;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget renderer;
    final lottieRenderer = const LottieRenderer();
    final svgRenderer = const SvgPoseRenderer();
    final fallbackRenderer = const FallbackRenderer();

    if (svgRenderer.canHandle(asset, poses)) {
      renderer = svgRenderer.build(context: context, asset: asset, poses: poses, height: height);
    } else if (lottieRenderer.canHandle(asset, poses)) {
      renderer = lottieRenderer.build(context: context, asset: asset, poses: poses, height: height);
    } else {
      renderer = fallbackRenderer.build(context: context, asset: asset, poses: poses, height: height);
    }

    return Semantics(
      image: true,
      label: '$label demonstration',
      child: Container(
        height: height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: renderer,
      ),
    );
  }
}
