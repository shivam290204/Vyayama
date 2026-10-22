import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/workouts/data/bodyweight_workout_flow.dart';

/// The "Workouts" section displaying exactly five bodyweight categories in order:
/// 1. Warm-up & Mobility
/// 2. Beginner Bodyweight Workout
/// 3. Intermediate Bodyweight Workout
/// 4. Advanced Bodyweight Workout
/// 5. Cool-down & Recovery
class BrowsePlansTab extends ConsumerWidget {
  const BrowsePlansTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workouts = BodyweightWorkoutCatalog.workouts;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bodyweight Workouts',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '5 structured routines: Warm-up, Guided Bodyweight Sessions & Recovery',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // The 5 Workout Cards in exact order
        for (final flow in workouts)
          _WorkoutCategoryCard(flow: flow),
      ],
    );
  }
}

class _WorkoutCategoryCard extends StatefulWidget {
  const _WorkoutCategoryCard({required this.flow});

  final BodyweightWorkoutFlow flow;

  @override
  State<_WorkoutCategoryCard> createState() => _WorkoutCategoryCardState();
}

class _WorkoutCategoryCardState extends State<_WorkoutCategoryCard> {
  bool _expanded = false;

  Color _getDifficultyColor(BuildContext context, BodyweightLevel level) {
    switch (level) {
      case BodyweightLevel.warmup:
        return const Color(0xFF0D9488); // Teal
      case BodyweightLevel.beginner:
        return const Color(0xFF2E7D32); // Forest Green
      case BodyweightLevel.intermediate:
        return const Color(0xFFD97706); // Warm Amber
      case BodyweightLevel.advanced:
        return const Color(0xFFC2410C); // Deep Flame / Rust
      case BodyweightLevel.cooldown:
        return const Color(0xFF2563EB); // Royal Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final diffColor = _getDifficultyColor(context, flow.level);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Illustration Banner
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                child: Image.asset(
                  flow.illustrationAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      flow.level.icon,
                      size: 64,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              // Difficulty Badge positioned at top right
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: diffColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    flow.badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category Title
                Text(
                  flow.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Metadata Badges (Duration, Exercises)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 15,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            flow.estimatedDuration,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Exercises count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            size: 14,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${flow.totalExerciseCount} exercises',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Short Description
                Text(
                  flow.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),

                // Expandable Exercise List Preview
                InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.format_list_bulleted_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _expanded
                                ? 'Hide exercises'
                                : 'View all ${flow.totalExerciseCount} exercises',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_expanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < flow.exercises.length; i++) ...[
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: cs.primaryContainer,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              flow.exercises[i].name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              flow.exercises[i].isTimed
                                  ? '${flow.exercises[i].durationSec}s · ${flow.exercises[i].restSec}s rest'
                                  : '${flow.exercises[i].reps} reps · ${flow.exercises[i].restSec}s rest',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: cs.outline,
                            ),
                            onTap: () => context.push(
                              AppRoutes.exercisePath(flow.exercises[i].exerciseId),
                            ),
                          ),
                          if (i < flow.exercises.length - 1)
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 48,
                              color: cs.outlineVariant.withValues(alpha: 0.2),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Primary "Start Workout" Button
                FilledButton.icon(
                  onPressed: () {
                    final plan = flow.toWorkoutPlan();
                    final day = plan.days.first;
                    context.push(AppRoutes.workoutSessionPath(day.id));
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    'Start ${flow.badge}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: diffColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
