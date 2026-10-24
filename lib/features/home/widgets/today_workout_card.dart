import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/plan_schedule.dart';
import 'package:fitbuddy/features/workouts/providers.dart';

/// Card on Home displaying today's scheduled workout from the user's active plan,
/// featuring the flat-vector athletic character illustration style.
class TodayWorkoutCard extends ConsumerWidget {
  const TodayWorkoutCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final planAsync = ref.watch(defaultPlanProvider);

    return planAsync.when(
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? AppPalette.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outline.withValues(alpha: isDark ? 0.5 : 1.0),
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (plan) {
        if (plan == null) return const SizedBox.shrink();

        final weekday = DateTime.now().weekday;
        final todayDay = plan.dayForWeekday(weekday);
        final nextDay = nextWorkoutDay(plan);
        final isRestDay = todayDay == null;

        final String title;
        final String subtitle;
        if (isRestDay) {
          title = 'Active Recovery Day';
          subtitle = nextDay != null
              ? 'Next: ${nextDay.name} on ${weekdayName(nextDay.dayNumber)}'
              : 'Rest & re-energize for tomorrow';
        } else {
          title = todayDay.name;
          subtitle = '${todayDay.exercises.length} exercises · ~${estimateDayMinutes(todayDay)} min';
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outline.withValues(alpha: isDark ? 0.5 : 1.0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : AppPalette.forestGreen.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Flat-vector athletic character illustration
                Container(
                  width: 84,
                  height: 84,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? context.colors.waterContainer
                        : AppPalette.softLime.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      isRestDay
                          ? 'assets/exercises/meditation.webp'
                          : 'assets/exercises/running.webp',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.fitness_center_rounded,
                        size: 40,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Workout details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isRestDay
                                  ? AppPalette.softCoral.withValues(alpha: 0.25)
                                  : AppPalette.limeGreen.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRestDay ? 'REST DAY' : 'TODAY\'S WORKOUT',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isRestDay
                                    ? context.colors.warning
                                    : (isDark ? AppPalette.limeGreen : AppPalette.forestGreen),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (todayDay != null)
                            FilledButton.icon(
                              onPressed: () => context.push(
                                AppRoutes.workoutSessionPath(todayDay.id),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 18),
                              label: const Text('Start'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(96, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () => context.push(AppRoutes.workouts),
                              icon: const Icon(Icons.explore_rounded, size: 16),
                              label: const Text('View Plan'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(96, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
