import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/challenges/widgets/challenge_progress_controls.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full card for today's challenge: description, progress and controls.
/// Handles loading, error and empty states.
class TodayChallengeCard extends ConsumerWidget {
  /// Creates the card.
  const TodayChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(todayChallengeProvider);
    final completed =
        ref.watch(challengesProvider).asData?.value.completedToday ?? false;
    final progress = ref.watch(todayProgressProvider);

    return challengeAsync.when(
      loading: () => const _Shell(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (_, __) => _Shell(
        child: Column(
          children: [
            Text(
              "We couldn't load today's challenge.",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(challengeCatalogProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      data: (challenge) => challenge == null
          ? _Shell(
              child: Text(
                'No challenge available today. Check back tomorrow!',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            )
          : _Content(
              challenge: challenge,
              completed: completed,
              progress: completed ? challenge.targetValue : progress,
            ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      );
}

class _Content extends StatelessWidget {
  const _Content({
    required this.challenge,
    required this.completed,
    required this.progress,
  });

  final Challenge challenge;
  final bool completed;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final label = '${formatInt(progress)} / '
        '${formatInt(challenge.targetValue)} ${challenge.type.unit}';
    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's challenge",
                  style: text.labelLarge?.copyWith(color: scheme.primary),
                ),
              ),
              Chip(
                avatar: const Icon(Icons.bolt, size: 18, semanticLabel: 'XP'),
                label: Text('${challenge.xp} XP'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(challenge.title, style: text.titleLarge),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(challenge.description, style: text.bodyMedium),
          ],
          const SizedBox(height: 16),
          Semantics(
            label: 'Challenge progress',
            value: label,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: challenge.fractionFor(progress),
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: text.bodySmall),
          const SizedBox(height: 12),
          if (completed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: scheme.onPrimaryContainer,
                    semanticLabel: 'Completed',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Completed! Great job showing up today.',
                      style: text.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ChallengeProgressControls(challenge: challenge),
        ],
      ),
    );
  }
}
