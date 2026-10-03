import 'package:fitbuddy/features/teams/data/team.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the team's invite code with copy and share buttons.
class InviteCodeCard extends ConsumerWidget {
  /// Creates the card.
  const InviteCodeCard({super.key, required this.team});

  /// The team whose code is shown.
  final Team team;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: team.inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    try {
      final message = await ref.read(inviteSharerProvider).share(
            'Join my Vyayama team "${team.name}"! Use invite code '
            '${team.inviteCode} in the app.',
          );
      if (message == null || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Invite friends', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Share this code so friends can join your team.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Semantics(
                label: 'Invite code ${team.inviteCode.split('').join(' ')}',
                child: ExcludeSemantics(
                  child: Text(
                    team.inviteCode,
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(
                      letterSpacing: 6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => _share(context, ref),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
