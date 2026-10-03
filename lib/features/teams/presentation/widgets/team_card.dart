import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/presentation/widgets/team_type_icon.dart';
import 'package:flutter/material.dart';

/// A tappable card for one team in the list.
class TeamCard extends StatelessWidget {
  /// Creates the card.
  const TeamCard({super.key, required this.team, required this.onTap});

  /// The team to show.
  final Team team;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final members =
        team.memberCount == 1 ? '1 member' : '${team.memberCount} members';
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            teamTypeIcon(team.type),
            color: scheme.onPrimaryContainer,
            semanticLabel: '${team.type.label} team',
          ),
        ),
        title: Text(team.name),
        subtitle: Text('${team.type.label} · $members'),
        trailing: const Icon(Icons.chevron_right, semanticLabel: 'Open team'),
      ),
    );
  }
}
