import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/data/async_value_x.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/wellness_app_bar.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/invite_code_card.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/leaderboard_widget.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/members_section.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/team_type_icon.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/weekly_goal_card.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Team detail: weekly goal, invite code, leaderboard and members.
class TeamDetailScreen extends ConsumerWidget {
  /// Creates the screen for the team with [teamId].
  const TeamDetailScreen({super.key, required this.teamId});

  /// Id of the team to show.
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = ref.watch(teamProvider(teamId));

    return Scaffold(
      appBar: WellnessAppBar(title: team.dataOrNull?.name ?? 'Team'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(teamProvider)
              ..invalidate(teamMembersProvider)
              ..invalidate(teamLeaderboardProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              AsyncValueView<Team?>(
                value: team,
                onRetry: () => ref.invalidate(teamProvider),
                builder: (data) =>
                    data == null ? const _NotFound() : _DetailBody(team: data),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              semanticLabel: 'Team not found',
            ),
            const SizedBox(height: 8),
            const Text(
              'We could not find this team. You may have left it.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => context.go(AppRoutes.teams),
              child: const Text('Back to teams'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.team});

  final Team team;

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave team?'),
        content: Text('You will no longer see ${team.name}. You can rejoin '
            'with the invite code.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(myTeamsProvider.notifier).leave(team.id);
      if (context.mounted) context.go(AppRoutes.teams);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not leave the team. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(teamsCurrentUserIdProvider);
    final isOwner = team.ownerId == me;
    final members = team.memberCount == 1 ? '1 member' : '${team.memberCount} members';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                teamTypeIcon(team.type),
                color: scheme.onPrimaryContainer,
                semanticLabel: '${team.type.label} team',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(team.name, style: text.titleLarge),
                  Text(
                    '${team.type.label} team · $members',
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        WeeklyGoalCard(team: team),
        const SizedBox(height: 16),
        LeaderboardWidget(team: team),
        const SizedBox(height: 16),
        InviteCodeCard(team: team),
        const SizedBox(height: 16),
        MembersSection(team: team),
        if (!isOwner) ...<Widget>[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _confirmLeave(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Leave team'),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
