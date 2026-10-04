import 'package:fitbuddy/features/home/widgets/progress_ring_painter.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// A single animated circular progress ring with an icon, value, and label.
///
/// [value] is the current metric value (e.g. steps walked).
/// [goal] is the daily goal (e.g. 8000 steps). If zero, progress shows 0%.
/// [ringColor] is the arc fill colour.
/// [trackColor] is the faint background track.
/// [icon] is displayed inside the ring.
/// [label] is shown below the value (e.g. "steps").
/// [semanticGoalLabel] is the unit for the semantics announcement
///   (e.g. "Steps: 5,566 of 8,000").
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    required this.goal,
    required this.ringColor,
    required this.trackColor,
    required this.icon,
    required this.label,
    required this.semanticGoalLabel,
    this.ringSize = 88.0,
    this.strokeWidth = 6.0,
  });

  final int value;
  final int goal;
  final Color ringColor;
  final Color trackColor;
  final IconData icon;
  final String label;
  final String semanticGoalLabel;
  final double ringSize;
  final double strokeWidth;

  /// Progress fraction clamped to [0, 1].
  static double progressFraction(int value, int goal) {
    if (goal <= 0) return 0.0;
    return (value / goal).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final textTheme = Theme.of(context).textTheme;
    final fraction = progressFraction(value, goal);
    final isComplete = goal > 0 && value >= goal;

    return Semantics(
      label: '$semanticGoalLabel: ${formatInt(value)} of ${formatInt(goal)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, animatedFraction, _) {
                return SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The ring.
                      CustomPaint(
                        size: Size.square(ringSize),
                        painter: ProgressRingPainter(
                          progress: animatedFraction,
                          ringColor: ringColor,
                          trackColor: trackColor,
                          strokeWidth: strokeWidth,
                        ),
                      ),
                      // Icon inside the ring.
                      Icon(icon, color: ringColor, size: ringSize * 0.3),
                      // Completion check badge.
                      if (isComplete)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _CompletionBadge(
                            color: ringColor,
                            reduceMotion: reduceMotion,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Animated value count-up.
          TweenAnimationBuilder<double>(
            tween: Tween(end: value.toDouble()),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, animatedVal, _) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatInt(animatedVal.round()),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            },
          ),
          Text(
            label,
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A small check badge shown when the goal is met.
class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({
    required this.color,
    required this.reduceMotion,
  });

  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 14),
    );

    if (reduceMotion) return badge;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: badge,
    );
  }
}

/// Loading skeleton placeholder for a ring.
class ProgressRingSkeleton extends StatelessWidget {
  const ProgressRingSkeleton({
    super.key,
    this.ringSize = 88.0,
    this.strokeWidth = 6.0,
  });

  final double ringSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final trackColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
            width: ringSize,
            height: ringSize,
            child: CustomPaint(
              size: Size.square(ringSize),
              painter: ProgressRingPainter(
                progress: 0.0,
                ringColor: trackColor,
                trackColor: trackColor,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 14,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 48,
          height: 10,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
