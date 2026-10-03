import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows how far the whole team is toward its shared weekly goal.
class WeeklyGoalCard extends ConsumerWidget {
  /// Creates the card.
  const WeeklyGoalCard({super.key, required this.team});

  /// The team to show.
  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final query = (teamId: team.id, period: LeaderboardPeriod.thisWeek);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Shared weekly goal', style: text.titleMedium),
            const SizedBox(height: 12),
            AsyncValueView<List<LeaderboardEntry>>(
              value: ref.watch(teamLeaderboardProvider(query)),
              onRetry: () => ref.invalidate(teamLeaderboardProvider),
              loadingHeight: 80,
              builder: (entries) {
                final total = entries.fold<int>(0, (sum, e) => sum + e.value);
                final target =
                    TeamGoals.teamWeeklyTarget(team.type, entries.length);
                final progress = TeamGoals.progress(total, target);
                final percent = (progress * 100).round();
                final message = percent >= 100
                    ? 'Goal reached! Amazing teamwork.'
                    : percent >= 50
                        ? 'More than halfway there. Keep it up!'
                        : 'Every bit counts. You can do this together!';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      label: 'Team goal progress, $percent percent. '
                          '${formatCount(total)} of ${formatCount(target)} '
                          '${team.type.unit} this week.',
                      child: ExcludeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${formatCount(total)} / ${formatCount(target)} '
                              '${team.type.unit}',
                              style: text.titleLarge
                                  ?.copyWith(color: scheme.primary),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$message  (${team.type.metricLabel}, this week)',
                      style: text.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
