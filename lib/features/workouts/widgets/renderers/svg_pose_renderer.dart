import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fitbuddy/features/workouts/widgets/renderers/exercise_renderer.dart';

class SvgPoseRenderer implements ExerciseRenderer {
  const SvgPoseRenderer();

  @override
  bool canHandle(String? asset, List<String> poses) {
    return poses.length >= 2 && poses.every((p) => p.endsWith('.svg'));
  }

  @override
  Widget build({
    required BuildContext context,
    required String? asset,
    required List<String> poses,
    required double height,
  }) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      return _StaticPoses(poses: poses, height: height);
    }
    return _AlternatingPoses(poses: poses, height: height);
  }
}

class _StaticPoses extends StatelessWidget {
  const _StaticPoses({required this.poses, required this.height});
  final List<String> poses;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _PoseItem(asset: poses[0], label: 'Start', height: height),
        _PoseItem(asset: poses[1], label: 'Finish', height: height),
      ],
    );
  }
}

class _AlternatingPoses extends StatefulWidget {
  const _AlternatingPoses({required this.poses, required this.height});
  final List<String> poses;
  final double height;

  @override
  State<_AlternatingPoses> createState() => _AlternatingPosesState();
}

class _AlternatingPosesState extends State<_AlternatingPoses> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % 2;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hard cut, no crossfade
    return _PoseItem(
      asset: widget.poses[_currentIndex],
      label: _currentIndex == 0 ? 'Start' : 'Finish',
      height: widget.height,
    );
  }
}

class _PoseItem extends StatelessWidget {
  const _PoseItem({required this.asset, required this.label, required this.height});
  final String asset;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          asset,
          height: height * 0.7,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
