import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/teams/data/team_repository.dart';
import 'package:fitbuddy/features/teams/domain/team_goals.dart';
import 'package:fitbuddy/features/teams/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Join a team by typing its invite code.
class JoinTeamCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const JoinTeamCard({super.key});

  @override
  ConsumerState<JoinTeamCard> createState() => _JoinTeamCardState();
}

class _JoinTeamCardState extends ConsumerState<JoinTeamCard> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = normalizeInviteCode(_controller.text);
    if (code.length != inviteCodeLength) {
      setState(() => _error = 'Invite codes have $inviteCodeLength characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final team = await ref.read(myTeamsProvider.notifier).join(code);
      if (!mounted) return;
      _controller.clear();
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You joined ${team.name}!')),
      );
      context.push(AppRoutes.teamDetailPath(team.id));
    } on TeamException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not join. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Join a team', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Got an invite code from a friend? Enter it here.',
              style: text.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 8,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9 \-]'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Invite code',
                      errorText: _error,
                      errorMaxLines: 3,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _busy ? null : _join(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 48),
                    ),
                    onPressed: _busy ? null : _join,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Join'),
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
