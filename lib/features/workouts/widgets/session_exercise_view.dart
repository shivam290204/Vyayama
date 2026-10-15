import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_animation.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_info_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The "work" phase: one exercise, 3D character form guide,
/// compressed YouTube video tutorial button, set counter, and rep target/timer.
class SessionExerciseView extends ConsumerWidget {
  const SessionExerciseView({
    super.key,
    required this.state,
    required this.onDoneSet,
  });

  final SessionState state;
  final VoidCallback onDoneSet;

  Future<void> _launchYouTube(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open YouTube')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open video: $e')),
        );
      }
    }
  }

  void _showEditVideoSheet(
      BuildContext context, WidgetRef ref, Exercise exercise, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
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
                        Text('YouTube Tutorial',
                            style: theme.textTheme.titleMedium),
                        Text(
                          'Change video link for ${exercise.name}',
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
                decoration: InputDecoration(
                  labelText: 'YouTube Video URL',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final url = controller.text.trim();
                  ref
                      .read(customExerciseVideosProvider.notifier)
                      .setVideoUrl(exercise.id, url);
                  Navigator.pop(ctx);
                },
                child: const Text('Save Video URL'),
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
    final item = state.current;
    final ex = item.exercise;
    final reps = item.prescription.reps;
    final total = item.prescription.durationSec ?? 0;

    final overrides = ref.watch(customExerciseVideosProvider);
    final videoUrl = overrides[ex.id] ?? ex.videoUrl;

    final bigText = item.timed
        ? formatClock(state.secondsLeft)
        : (reps == null ? 'Go at your pace' : '$reps reps');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Exercise ${state.index + 1} of ${state.items.length}',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(ex.name,
              textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          // 3D Character Exercise Pose
          ExerciseAnimation(
            asset: ex.animationAsset,
            characterAsset: ex.characterAsset,
            poses: ex.poses,
            label: ex.name,
            height: 200,
          ),
          const SizedBox(height: 10),
          // Compressed YouTube Video Tutorial button
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (videoUrl != null && videoUrl.isNotEmpty) {
                        _launchYouTube(context, videoUrl);
                      } else {
                        _showEditVideoSheet(context, ref, ex, '');
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: Color(0xFFFF0000),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            videoUrl != null && videoUrl.isNotEmpty
                                ? 'Watch Video Tutorial'
                                : 'Add YouTube Video',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  tooltip: 'Change YouTube URL',
                  color: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _showEditVideoSheet(context, ref, ex, videoUrl ?? ''),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Workout: ${formatClock(state.elapsedSeconds)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Set ${state.setIndex + 1} of ${item.sets}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Semantics(
            label: item.timed
                ? '${state.secondsLeft} seconds left'
                : (reps == null ? 'Go at your pace' : '$reps reps'),
            child: ExcludeSemantics(
              child: Text(
                bigText,
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  color: cs.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          if (item.timed && total > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ((total - state.secondsLeft) / total)
                  .clamp(0.0, 1.0)
                  .toDouble(),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
          if (state.paused) ...[
            const SizedBox(height: 8),
            Text('Paused',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: cs.tertiary)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: state.paused ? null : onDoneSet,
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.check_rounded),
            label: Text(item.timed ? 'Done early' : 'Done set'),
          ),
          TextButton.icon(
            onPressed: () => showExerciseHowTo(context, ex),
            icon: const Icon(Icons.help_outline),
            label: const Text('How to do it'),
          ),
        ],
      ),
    );
  }
}
