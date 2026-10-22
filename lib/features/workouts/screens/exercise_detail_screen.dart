import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/contraindication_chips.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_animation.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_info_sheet.dart';
import 'package:fitbuddy/features/workouts/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// `/workouts/exercise/:id`: animation, instructions, mistakes and warnings.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseByIdProvider(exerciseId));
    final tags = ref.watch(selectedConditionTagsProvider);

    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const WorkoutLoading()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: WorkoutErrorView(
          onRetry: () => ref.invalidate(exerciseByIdProvider(exerciseId)),
        ),
      ),
      data: (exercise) {
        if (exercise == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const WorkoutMessageView(
              icon: Icons.search_off_rounded,
              title: 'Exercise not found',
            ),
          );
        }
        return _Body(exercise: exercise, userTags: tags);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.exercise, required this.userTags});

  final Exercise exercise;
  final List<String> userTags;

  Future<void> _launchYouTube(
      BuildContext context, String? url, String fallbackSearchTerm) async {
    Uri? uri;
    if (url != null && url.trim().isNotEmpty) {
      uri = Uri.tryParse(url.trim());
    }
    final isYoga = exercise.muscleGroup.toLowerCase() == 'yoga' ||
        exercise.id.toLowerCase().contains('yoga') ||
        exercise.name.toLowerCase().contains('pose') ||
        exercise.name.toLowerCase().contains('asana');
    final querySuffix = isYoga ? 'yoga tutorial' : 'exercise tutorial';

    uri ??= Uri.parse(
        'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$fallbackSearchTerm $querySuffix')}');

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        final fallbackUri = Uri.parse(
            'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$fallbackSearchTerm $querySuffix')}');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open video: $e')),
          );
        }
      }
    }
  }

  void _showEditVideoSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: exercise.videoUrl ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.smart_display_rounded,
                      color: Color(0xFFFF0000),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Workout Video on YouTube',
                            style: theme.textTheme.titleMedium),
                        Text(
                          'Add or edit tutorial for ${exercise.name}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'YouTube Video Link or ID',
                  hintText: 'e.g. https://www.youtube.com/watch?v=... or ID',
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final newUrl = controller.text.trim();
                      ref
                          .read(customExerciseVideosProvider.notifier)
                          .setVideoUrl(exercise.id, newUrl);
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(newUrl.isEmpty
                              ? 'Video link cleared'
                              : 'YouTube workout video saved!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final clash = exercise.conflictsWith(userTags);
    final videoId = exercise.youtubeVideoId;
    final hasVideo = exercise.videoUrl != null && exercise.videoUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 3D character demonstration
          ExerciseAnimation(
            asset: exercise.animationAsset,
            characterAsset: exercise.characterAsset,
            poses: exercise.poses,
            label: exercise.name,
            height: 240,
          ),
          const SizedBox(height: 16),
          Text(exercise.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                avatar: const Icon(Icons.accessibility_new, size: 18),
                label: Text(prettyLabel(exercise.muscleGroup)),
              ),
              Chip(
                avatar: const Icon(Icons.fitness_center, size: 18),
                label: Text(prettyLabel(exercise.equipment)),
              ),
            ],
          ),
          if (clash.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: cs.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: cs.onErrorContainer, semanticLabel: 'Warning'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This exercise may not suit your selected conditions '
                        '(${clash.map((t) => prettyLabel(t).toLowerCase()).join(', ')}). '
                        'Please check with your doctor or choose a gentler option.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // YouTube Video Tutorial Card
          _buildYouTubeCard(context, ref, hasVideo, videoId),

          const SizedBox(height: 24),
          Text('How to do it', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ExerciseSteps(steps: exercise.instructions),
          if (exercise.commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Common mistakes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ExerciseMistakes(mistakes: exercise.commonMistakes),
          ],
          if (exercise.contraindications.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Take extra care if you have issues with',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ContraindicationChips(
              tags: exercise.contraindications,
              highlight: clash,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'General wellness information, not medical advice. Consult a '
            'qualified doctor before starting any exercise program, and stop '
            'if you feel pain, dizziness or chest discomfort.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildYouTubeCard(
    BuildContext context,
    WidgetRef ref,
    bool hasVideo,
    String? videoId,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (videoId != null || hasVideo) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF0000).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              _launchYouTube(context, exercise.videoUrl, exercise.name);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Compact preview thumbnail with rounded corners and play badge
                  if (videoId != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 84,
                        height: 50,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.black26,
                                child: const Icon(Icons.smart_display_rounded,
                                    color: Color(0xFFFF0000), size: 24),
                              ),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.28),
                            ),
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Color(0xFFFF0000),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFFFF0000),
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Video title & YouTube indicator
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0000),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'YouTube',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Video Tutorial',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Tap to watch tutorial',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 11,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Edit button
                  IconButton(
                    tooltip: 'Edit video URL',
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _showEditVideoSheet(context, ref),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Fallback when no video is attached
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_display_outlined,
              color: Colors.white54, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No video tutorial attached yet',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _showEditVideoSheet(context, ref),
            icon: const Icon(Icons.add_link_rounded, size: 16),
            label: const Text('Add Link', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}
