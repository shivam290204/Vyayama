import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// List of the team's members.
class MembersSection extends ConsumerWidget {
  /// Creates the section.
  const MembersSection({super.key, required this.team});

  /// The team whose members are listed.
  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(teamsCurrentUserIdProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Members', style: text.titleMedium),
            const SizedBox(height: 8),
            AsyncValueView<List<TeamMember>>(
              value: ref.watch(teamMembersProvider(team.id)),
              onRetry: () => ref.invalidate(teamMembersProvider),
              builder: (members) {
                if (members.isEmpty) {
                  return Text('No members to show.', style: text.bodyMedium);
                }
                return Column(
                  children: <Widget>[
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            _initial(member.displayName),
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                        ),
                        title: Text(
                          member.userId == me
                              ? '${_name(member)} (You)'
                              : _name(member),
                        ),
                        trailing: member.userId == team.ownerId
                            ? Chip(
                                label: const Text('Owner'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: scheme.tertiaryContainer,
                              )
                            : null,
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

  String _name(TeamMember member) =>
      member.displayName.isEmpty ? 'Member' : member.displayName;

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
