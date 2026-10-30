import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/widgets/animated_section_header.dart';
import 'package:fitbuddy/features/intelligence/domain/models/fitness_insight.dart';
import 'package:fitbuddy/features/intelligence/providers.dart';

/// Presentation card section displaying deterministic, personalised fitness insights.
///
/// Features:
/// 1. Connects seamlessly with [fitnessInsightsProvider].
/// 2. Collapses to [SizedBox.shrink] if disabled by feature flag or when no insights exist.
/// 3. Follows Vyayama's flat-vector, modern card aesthetic.
class SmartInsightsSection extends ConsumerWidget {
  const SmartInsightsSection({
    super.key,
    this.headerDelay = Duration.zero,
  });

  final Duration headerDelay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(fitnessInsightsProvider);

    return insightsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (insights) {
        if (insights.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSectionHeader(
              title: 'Smart Insights',
              icon: Icons.auto_awesome_rounded,
              delay: headerDelay,
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: insights.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final insight = insights[index];
                return _InsightCard(insight: insight);
              },
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final FitnessInsight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final (icon, iconColor, bgColor) =
        _resolveCategoryStyle(insight.category, scheme, isDark);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.4 : 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : AppPalette.forestGreen.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Semantic Category Icon Badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        insight.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (insight.priority == InsightPriority.urgent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Notice',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: scheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (insight.actionLabel != null && insight.actionRoute != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () {
                        try {
                          context.go(insight.actionRoute!);
                        } catch (_) {
                          // Safe route navigation fallback
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              insight.actionLabel!,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _resolveCategoryStyle(
    InsightCategory category,
    ColorScheme scheme,
    bool isDark,
  ) {
    switch (category) {
      case InsightCategory.consistency:
        return (
          Icons.fitness_center_rounded,
          AppPalette.forestGreen,
          AppPalette.forestGreen.withValues(alpha: isDark ? 0.25 : 0.12),
        );
      case InsightCategory.recovery:
        return (
          Icons.self_improvement_rounded,
          AppPalette.deepCoral,
          AppPalette.deepCoral.withValues(alpha: isDark ? 0.25 : 0.12),
        );
      case InsightCategory.streak:
        return (
          Icons.local_fire_department_rounded,
          scheme.tertiary,
          scheme.tertiary.withValues(alpha: isDark ? 0.25 : 0.12),
        );
      case InsightCategory.activityChange:
        return (
          Icons.trending_up_rounded,
          scheme.secondary,
          scheme.secondary.withValues(alpha: isDark ? 0.25 : 0.12),
        );
      case InsightCategory.workoutPattern:
        return (
          Icons.schedule_rounded,
          scheme.primary,
          scheme.primary.withValues(alpha: isDark ? 0.25 : 0.12),
        );
      case InsightCategory.recommendation:
        return (
          Icons.stars_rounded,
          AppPalette.limeGreen,
          AppPalette.limeGreen.withValues(alpha: isDark ? 0.25 : 0.12),
        );
    }
  }
}
