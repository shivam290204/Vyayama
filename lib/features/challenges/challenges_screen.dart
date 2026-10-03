import 'package:fitbuddy/features/challenges/challenges_state.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/challenges/widgets/badge_grid.dart';
import 'package:fitbuddy/features/challenges/widgets/completion_history_list.dart';
import 'package:fitbuddy/features/challenges/widgets/streak_flame.dart';
import 'package:fitbuddy/features/challenges/widgets/today_challenge_card.dart';
import 'package:fitbuddy/features/challenges/widgets/xp_level_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's challenge, streak flame, XP and level, badges and history.
class ChallengesScreen extends ConsumerWidget {
  /// Creates the screen.
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ChallengeReward?>(
      challengesProvider.select((a) => a.asData?.value.lastReward),
      (previous, next) {
        if (next == null) return;
        final milestone = next.milestone == null
            ? ''
            : ' ${next.milestone}-day streak milestone!';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Challenge complete! +${next.xp} XP.$milestone'),
            ),
          );
      },
    );

    final state = ref.watch(challengesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: state.when(
        loading: () => Center(
          child: Semantics(
            label: 'Loading challenges',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                  semanticLabel: 'Error',
                ),
                const SizedBox(height: 12),
                Text(
                  "We couldn't load your challenges.",
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(challengesProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (s) => _Body(state: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final ChallengesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final streak = state.currentStreak;
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(challengeCatalogProvider)
          ..invalidate(challengesProvider);
        await ref.read(challengesProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const TodayChallengeCard(),
          const SizedBox(height: 12),
          StreakFlame(
            days: streak,
            longest: state.streak.longest > streak ? state.streak.longest : streak,
            activeToday: state.activeToday,
          ),
          const SizedBox(height: 12),
          XpLevelBar(level: state.level, totalXp: state.streak.xp),
          const SizedBox(height: 24),
          Text('Badges', style: text.titleMedium),
          const SizedBox(height: 8),
          BadgeGrid(earned: state.earnedBadgeIds),
          const SizedBox(height: 24),
          Text('Previous completions', style: text.titleMedium),
          const SizedBox(height: 4),
          CompletionHistoryList(entries: ref.watch(completionHistoryProvider)),
        ],
      ),
    );
  }
}
