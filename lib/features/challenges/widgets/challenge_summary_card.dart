import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/widgets/bouncing_card.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Compact challenge card for Home. Tapping opens the Challenges screen.
class ChallengeSummaryCard extends ConsumerWidget {
  /// Creates the card.
  const ChallengeSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(todayChallengeProvider);
    final completed =
        ref.watch(challengesProvider).asData?.value.completedToday ?? false;
    final progress = ref.watch(todayProgressProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (challengeAsync.isLoading) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (challengeAsync.hasError) {
      body = ListTile(
        leading: const Icon(Icons.error_outline, semanticLabel: 'Error'),
        title: const Text("Couldn't load today's challenge"),
        trailing: TextButton(
          onPressed: () => ref.invalidate(challengeCatalogProvider),
          child: const Text('Retry'),
        ),
      );
    } else {
      final challenge = challengeAsync.asData?.value;
      if (challenge == null) {
        body = const ListTile(
          leading: Icon(Icons.emoji_events_outlined),
          title: Text('No challenge today'),
        );
      } else {
        final shown = completed ? challenge.targetValue : progress;
        body = InkWell(
          onTap: () => context.push(AppRoutes.challenges),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    completed ? Icons.check_circle : Icons.emoji_events,
                    size: 32,
                    color: completed ? scheme.primary : scheme.tertiary,
                    semanticLabel:
                        completed ? 'Challenge completed' : "Today's challenge",
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          style: text.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          label: 'Challenge progress',
                          value: '${formatInt(shown)} of '
                              '${formatInt(challenge.targetValue)} '
                              '${challenge.type.unit}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: challenge.fractionFor(shown),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          completed
                              ? 'Done! +${challenge.xp} XP earned'
                              : '${formatInt(shown)} / '
                                  '${formatInt(challenge.targetValue)} '
                                  '${challenge.type.unit} · ${challenge.xp} XP',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, semanticLabel: 'Open'),
                ],
              ),
            ),
          ),
        );
      }
    }
    return BouncingCard(
      margin: EdgeInsets.zero,
      child: body,
    );
  }
}
