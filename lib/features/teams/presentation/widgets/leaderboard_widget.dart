import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Team leaderboard with a This week / This month toggle.
class LeaderboardWidget extends ConsumerStatefulWidget {
  /// Creates the leaderboard for [team].
  const LeaderboardWidget({super.key, required this.team});

  /// The team to rank.
  final Team team;

  @override
  ConsumerState<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends ConsumerState<LeaderboardWidget> {
  LeaderboardPeriod _period = LeaderboardPeriod.thisWeek;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(teamsCurrentUserIdProvider);
    final team = widget.team;
    final board = ref.watch(
      teamLeaderboardProvider((teamId: team.id, period: _period)),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Leaderboard', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${team.type.metricLabel}. Friendly competition, cheering each '
              'other on!',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SegmentedButton<LeaderboardPeriod>(
              style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
              showSelectedIcon: false,
              segments: <ButtonSegment<LeaderboardPeriod>>[
                for (final period in LeaderboardPeriod.values)
                  ButtonSegment<LeaderboardPeriod>(
                    value: period,
                    label: Text(period.label),
                  ),
              ],
              selected: <LeaderboardPeriod>{_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 12),
            AsyncValueView<List<LeaderboardEntry>>(
              value: board,
              onRetry: () => ref.invalidate(teamLeaderboardProvider),
              builder: (entries) {
                if (entries.isEmpty || entries.every((e) => e.value == 0)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'No activity yet ${_period.label.toLowerCase()}. '
                        'Be the first to get moving!',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                    ),
                  );
                }
                return Column(
                  children: <Widget>[
                    for (final entry in entries)
                      _LeaderboardRow(
                        entry: entry,
                        unit: team.type.unit,
                        isMe: entry.userId == me,
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

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.unit,
    required this.isMe,
  });

  final LeaderboardEntry entry;
  final String unit;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final value = '${formatCount(entry.value)} $unit';
    final label = 'Rank ${entry.rank}, ${entry.name}'
        '${isMe ? ', you' : ''}, $value';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: isMe ? scheme.secondaryContainer : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 32,
                child: Center(
                  child: entry.rank == 1
                      ? Icon(Icons.emoji_events, color: scheme.tertiary)
                      : Text('${entry.rank}', style: text.titleSmall),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isMe ? '${entry.name} (You)' : entry.name,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge,
                ),
              ),
              const SizedBox(width: 8),
              Text(value, style: text.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
