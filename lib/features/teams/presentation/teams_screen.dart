import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/wellness_app_bar.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/join_team_card.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/team_card.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:fitbuddy/features/teams/teams_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Teams home: join with a code, create a team and see your teams.
class TeamsScreen extends ConsumerWidget {
  /// Creates the screen.
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const WellnessAppBar(title: 'Teams'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myTeamsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const JoinTeamCard(),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(child: Text('My teams', style: text.titleMedium)),
                  FilledButton.tonalIcon(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: () => context.push(teamsCreatePath),
                    icon: const Icon(Icons.add),
                    label: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AsyncValueView<List<Team>>(
                value: ref.watch(myTeamsProvider),
                onRetry: () => ref.invalidate(myTeamsProvider),
                builder: (teams) {
                  if (teams.isEmpty) return const _EmptyTeams();
                  return Column(
                    children: <Widget>[
                      for (final team in teams)
                        TeamCard(
                          team: team,
                          onTap: () =>
                              context.push(AppRoutes.teamDetailPath(team.id)),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTeams extends StatelessWidget {
  const _EmptyTeams();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.groups_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
              semanticLabel: 'No teams yet',
            ),
            const SizedBox(height: 8),
            Text(
              'No teams yet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Create a team for you and your friends, or join one with an '
              'invite code. Moving together is more fun!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
