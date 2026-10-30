import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_palette.dart';
import 'package:fitbuddy/features/intelligence/domain/models/workout_difficulty_feedback.dart';
import 'package:fitbuddy/features/intelligence/providers.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';

/// Optional post-workout difficulty feedback card presented on session finish.
///
/// Collects 3-tier feedback (Too Easy, Just Right, Too Hard) to inform
/// adaptive progressive overload and deload recommendations.
class PostWorkoutFeedbackCard extends ConsumerStatefulWidget {
  const PostWorkoutFeedbackCard({
    super.key,
    required this.planDayId,
    this.workoutLogId,
  });

  final String planDayId;
  final String? workoutLogId;

  @override
  ConsumerState<PostWorkoutFeedbackCard> createState() =>
      _PostWorkoutFeedbackCardState();
}

class _PostWorkoutFeedbackCardState
    extends ConsumerState<PostWorkoutFeedbackCard> {
  WorkoutDifficultyRating? _selectedRating;
  bool _submitted = false;

  Future<void> _submit(WorkoutDifficultyRating rating) async {
    if (_submitted) return;
    setState(() {
      _selectedRating = rating;
      _submitted = true;
    });

    final uid =
        ref.read(currentProfileProvider).asData?.value?.id ?? 'local_user';
    final repo = ref.read(difficultyFeedbackRepositoryProvider);

    final feedback = WorkoutDifficultyFeedback(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      planDayId: widget.planDayId,
      completedAt: DateTime.now(),
      rating: rating,
      workoutLogId: widget.workoutLogId,
      createdAt: DateTime.now(),
    );

    await repo.recordFeedback(feedback);
    ref.invalidate(recentWorkoutFeedbackProvider);
    ref.invalidate(adaptiveJourneyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = ref.watch(intelligenceEnabledProvider);
    if (!isEnabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'How did this workout feel?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your optional feedback helps Vyayama fine-tune your next session.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (_submitted) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Feedback noted (${_selectedRating?.label ?? ''})! Future sessions will adjust accordingly.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      label: 'Too Easy',
                      icon: Icons.sentiment_satisfied_rounded,
                      color: AppPalette.limeGreen,
                      onTap: () => _submit(WorkoutDifficultyRating.tooEasy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      label: 'Just Right',
                      icon: Icons.thumb_up_alt_rounded,
                      color: cs.primary,
                      onTap: () => _submit(WorkoutDifficultyRating.justRight),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      label: 'Too Hard',
                      icon: Icons.fitness_center_rounded,
                      color: AppPalette.deepCoral,
                      onTap: () => _submit(WorkoutDifficultyRating.tooHard),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

