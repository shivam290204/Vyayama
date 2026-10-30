import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/maps/domain/models/saved_route.dart';
import 'package:flutter/material.dart';

/// Card presenting a discovered or saved outdoor route.
class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.onTap,
    this.onSaveToggle,
    this.isSaved = false,
  });

  final SavedRoute route;
  final VoidCallback onTap;
  final VoidCallback? onSaveToggle;
  final bool isSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? AppPalette.darkSurfaceContainer
        : AppPalette.lightSurface;
    final borderColor =
        isDark ? AppPalette.darkOutline : AppPalette.lightOutline;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Activity Icon, Title, and Bookmark button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppPalette.limeGreen.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      route.activityType.icon,
                      color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          route.surfaceType == RouteSurface.unknown
                              ? '${route.activityType.label} • ${route.isLoop ? 'Loop' : 'Out & Back'}'
                              : '${route.activityType.label} • ${route.surfaceType.name.toUpperCase()} • ${route.isLoop ? 'Loop' : 'Out & Back'}',
                          style: TextStyle(
                            color: textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onSaveToggle != null)
                    IconButton(
                      icon: Icon(
                        isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                        color: isSaved ? AppPalette.limeGreen : textMuted,
                      ),
                      tooltip: isSaved ? 'Remove from Saved' : 'Save Route',
                      onPressed: onSaveToggle,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Metrics Row: Distance, Time, Elevation, Difficulty
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetricItem(
                    label: 'Distance',
                    value: route.formattedDistance,
                    icon: Icons.straighten_rounded,
                    color: AppPalette.activitySteps,
                  ),
                  _MetricItem(
                    label: 'Est. Time',
                    value: route.formattedDuration,
                    icon: Icons.schedule_rounded,
                    color: AppPalette.activityMinutes,
                  ),
                  _MetricItem(
                    label: 'Elevation',
                    value: route.formattedElevation,
                    icon: Icons.terrain_rounded,
                    color: AppPalette.activityCalories,
                  ),
                  _DifficultyBadge(
                    difficulty: route.difficulty,
                    isEstimated: route.isDifficultyEstimated,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppPalette.darkText : AppPalette.lightText;
    final textMuted =
        isDark ? AppPalette.darkTextMuted : AppPalette.lightTextMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({
    required this.difficulty,
    this.isEstimated = false,
  });

  final RouteDifficulty difficulty;
  final bool isEstimated;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (difficulty) {
      case RouteDifficulty.easy:
        bg = AppPalette.limeGreen.withValues(alpha: 0.16);
        fg = AppPalette.limeGreen;
        label = isEstimated ? 'Est. Easy' : 'Easy';
        break;
      case RouteDifficulty.moderate:
        bg = AppPalette.activityMinutes.withValues(alpha: 0.16);
        fg = AppPalette.activityMinutes;
        label = isEstimated ? 'Est. Moderate' : 'Moderate';
        break;
      case RouteDifficulty.hard:
        bg = AppPalette.softCoral.withValues(alpha: 0.20);
        fg = AppPalette.deepCoral;
        label = isEstimated ? 'Est. Hard' : 'Hard';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
