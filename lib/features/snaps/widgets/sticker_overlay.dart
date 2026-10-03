import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:flutter/material.dart';

/// Activity, time and steps stickers drawn over the photo.
class StickerOverlay extends StatelessWidget {
  const StickerOverlay({
    super.key,
    required this.activity,
    required this.showActivity,
    required this.showTime,
    required this.showSteps,
    this.steps,
  });

  final ActivityType? activity;
  final bool showActivity;
  final bool showTime;
  final bool showSteps;
  final int? steps;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      if (showActivity && activity != null)
        _Pill(icon: activity!.icon, text: activity!.label),
      if (showTime)
        _Pill(icon: Icons.schedule, text: TimeOfDay.now().format(context)),
      if (showSteps && steps != null)
        _Pill(icon: Icons.directions_walk, text: '$steps steps'),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Wrap(spacing: 8, runSpacing: 8, children: pills),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSurface),
          const SizedBox(width: 6),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
