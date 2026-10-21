import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/yoga_flow.dart';
import 'package:fitbuddy/features/workouts/providers.dart';

/// Interactive Yoga section tab inside the Workout feature.
///
/// Provides 6 curated categories, verified YouTube video links,
/// step-by-step guidance, easier modifications, and pose breakdowns.
class YogaSectionTab extends ConsumerStatefulWidget {
  const YogaSectionTab({super.key});

  @override
  ConsumerState<YogaSectionTab> createState() => _YogaSectionTabState();
}

class _YogaSectionTabState extends ConsumerState<YogaSectionTab> {
  YogaCategory? _selectedCategory;
  int? _maxDurationMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercisesAsync = ref.watch(exerciseLibraryProvider);

    var filteredFlows = YogaCatalog.flows;
    if (_selectedCategory != null) {
      filteredFlows =
          filteredFlows.where((f) => f.category == _selectedCategory).toList();
    }
    if (_maxDurationMinutes != null) {
      filteredFlows =
          filteredFlows.where((f) => f.durationMinutes <= _maxDurationMinutes!).toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Categories'),
                selected: _selectedCategory == null,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = null);
                },
              ),
              const SizedBox(width: 8),
              for (final cat in YogaCategory.values) ...[
                FilterChip(
                  avatar: Icon(cat.icon, size: 16),
                  label: Text(cat.label),
                  selected: _selectedCategory == cat,
                  onSelected: (selected) {
                    setState(() => _selectedCategory = selected ? cat : null);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Duration Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(
                'Duration:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Any length'),
                selected: _maxDurationMinutes == null,
                onSelected: (selected) {
                  if (selected) setState(() => _maxDurationMinutes = null);
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('≤ 10 mins'),
                selected: _maxDurationMinutes == 10,
                onSelected: (selected) {
                  setState(() => _maxDurationMinutes = selected ? 10 : null);
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('≤ 15 mins'),
                selected: _maxDurationMinutes == 15,
                onSelected: (selected) {
                  setState(() => _maxDurationMinutes = selected ? 15 : null);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Result count
        Text(
          '${filteredFlows.length} Yoga ${filteredFlows.length == 1 ? 'Flow' : 'Flows'} Available',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Flow Cards
        for (final flow in filteredFlows)
          _YogaFlowCard(
            flow: flow,
            allExercises: exercisesAsync.value ?? const [],
          ),
      ],
    );
  }
}

class _YogaFlowCard extends StatelessWidget {
  const _YogaFlowCard({
    required this.flow,
    required this.allExercises,
  });

  final YogaFlow flow;
  final List<Exercise> allExercises;

  Future<void> _launchVideo(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video URL.')),
        );
      }
    }
  }

  void _showPoseDetailsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final exerciseMap = {for (final e in allExercises) e.id: e};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(flow.category.icon, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        flow.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  flow.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Breathing guidance
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.air_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Breathing Guidance',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              flow.breathingGuidance,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Easier Modifications
                Text(
                  'Easier Modifications',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (final mod in flow.modifications)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(mod, style: theme.textTheme.bodySmall)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),

                // Step-by-Step Poses
                Text(
                  'Sequence of Poses (${flow.exerciseIds.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < flow.exerciseIds.length; i++) ...[
                  Builder(
                    builder: (c) {
                      final exId = flow.exerciseIds[i];
                      final ex = exerciseMap[exId];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.secondaryContainer,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            ex?.name ?? exId,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            ex != null && ex.instructions.isNotEmpty
                                ? ex.instructions.first
                                : 'Tap to see step-by-step form and breathing',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            context.push(AppRoutes.exercisePath(exId));
                          },
                        ),
                      );
                    },
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row: Category Badge, Difficulty, Duration
            Row(
              children: [
                Icon(
                  flow.category.icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  flow.category.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${flow.durationMinutes} min',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    flow.difficulty,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Title & Description
            Text(
              flow.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              flow.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Breathing banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.air_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      flow.breathingGuidance,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showPoseDetailsSheet(context),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: const Text('Pose Cues'),
                ),
                if (flow.videoUrl != null)
                  OutlinedButton.icon(
                    onPressed: () => _launchVideo(context, flow.videoUrl!),
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                    label: const Text('Video'),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    context.push(AppRoutes.workoutPlanPath(flow.id));
                  },
                  icon: const Icon(Icons.assignment_outlined, size: 18),
                  label: const Text('Plan'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final plan = flow.toWorkoutPlan();
                    final day = plan.days.first;
                    context.push(AppRoutes.workoutSessionPath(day.id));
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start Flow'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
