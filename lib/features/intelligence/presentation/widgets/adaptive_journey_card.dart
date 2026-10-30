import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/intelligence/domain/models/journey_recommendation.dart';
import 'package:fitbuddy/features/intelligence/presentation/widgets/weekly_review_sheet.dart';
import 'package:fitbuddy/features/intelligence/providers.dart';

/// Card widget presenting the user's Adaptive Fitness Journey status and next recommendations.
class AdaptiveJourneyCard extends ConsumerWidget {
  const AdaptiveJourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(intelligenceEnabledProvider);
    if (!isEnabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final journeyAsync = ref.watch(adaptiveJourneyProvider);

    return journeyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (journey) {
        if (journey == null) return const SizedBox.shrink();

        final statusColor = _statusColor(journey.journeyStatus, cs);
        final statusBg = statusColor.withValues(alpha: 0.12);

        return Card(
          elevation: 0,
          color: cs.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Title and Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        size: 20,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Adaptive Fitness Journey',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            journey.goalTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        journey.journeyStatus.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Weekly progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly target: ${journey.completedSessionsThisWeek} of ${journey.weeklyTargetSessions} workouts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${journey.remainingSessionsThisWeek} remaining',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: journey.weeklyTargetSessions > 0
                            ? (journey.completedSessionsThisWeek /
                                    journey.weeklyTargetSessions)
                                .clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          journey.completedSessionsThisWeek >=
                                  journey.weeklyTargetSessions
                              ? AppPalette.forestGreen
                              : cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Next Recommended Workout Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            journey.isRecovery
                                ? Icons.self_improvement_rounded
                                : Icons.fitness_center_rounded,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              journey.recommendedNextWorkoutTitle,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${journey.suggestedDurationMinutes}m',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        journey.recommendationReason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (journey.adaptationNotes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final note in journey.adaptationNotes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (journey.recommendedPlanDayId != null &&
                              journey.recommendedPlanDayId!.isNotEmpty) {
                            context.push(
                              AppRoutes.workoutSessionPath(
                                journey.recommendedPlanDayId!,
                              ),
                            );
                          } else {
                            context.push(AppRoutes.workouts);
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          journey.isRecovery ? 'Start Recovery' : 'Start Workout',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final review =
                              await ref.read(weeklyFitnessReviewProvider.future);
                          if (review != null && context.mounted) {
                            WeeklyReviewSheet.show(context, review);
                          }
                        },
                        icon: const Icon(Icons.summarize_outlined, size: 18),
                        label: const Text('Review'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(JourneyStatus status, ColorScheme cs) {
    switch (status) {
      case JourneyStatus.progressingSteadily:
        return AppPalette.forestGreen;
      case JourneyStatus.activeRecovery:
        return AppPalette.deepCoral;
      case JourneyStatus.momentumRestart:
        return cs.tertiary;
      case JourneyStatus.buildingHabit:
      case JourneyStatus.maintaining:
        return cs.primary;
    }
  }
}

