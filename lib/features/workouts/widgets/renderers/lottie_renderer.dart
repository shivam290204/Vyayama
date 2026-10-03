import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/exercise_renderer.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/fallback_renderer.dart';

class LottieRenderer implements ExerciseRenderer {
  const LottieRenderer();

  @override
  bool canHandle(String? asset, List<String> poses) {
    return asset != null && asset.endsWith('.json');
  }

  @override
  Widget build({
    required BuildContext context,
    required String? asset,
    required List<String> poses,
    required double height,
  }) {
    if (asset == null) return const SizedBox.shrink();
    
    return Lottie.asset(
      asset,
      fit: BoxFit.contain,
      animate: !MediaQuery.of(context).disableAnimations,
      errorBuilder: (context, error, stackTrace) => FallbackRenderer().build(
        context: context,
        asset: asset,
        poses: poses,
        height: height,
      ),
    );
  }
}
