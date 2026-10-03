import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/friend_avatar.dart';
import 'package:fitbuddy/features/friends/widgets/my_qr_card.dart';
import 'package:fitbuddy/features/friends/widgets/qr_scan_sheet.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/friends/add`: exact-username search, my QR code, scan, share.
class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  final _controller = TextEditingController();
  bool _searching = false;
  bool _searched = false;
  String? _error;
  FriendUser? _found;
  FriendRelation _relation = FriendRelation.none;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? query]) async {
    final q = (query ?? _controller.text).trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    try {
      final repo = ref.read(friendRepositoryProvider);
      final user = await repo.findByUsername(q);
      final relation =
          user == null ? FriendRelation.none : await repo.relationTo(user.id);
      if (!mounted) return;
      setState(() {
        _found = user;
        _relation = relation;
        _searched = true;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not search right now. Try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _scan() async {
    final raw = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QrScanSheet(),
    );
    if (raw == null || !mounted) return;
    final name = parseInviteUsername(raw);
    if (name == null) {
      setState(() => _error = 'That QR code is not a Vyayama invite.');
      return;
    }
    _controller.text = name;
    await _search(name);
  }

  Future<void> _sendRequest(FriendUser user) async {
    try {
      await ref.read(friendRepositoryProvider).sendRequest(user.id);
      ref.invalidate(friendRequestsProvider);
      if (!mounted) return;
      setState(() => _relation = FriendRelation.requestSent);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${user.name} 💪')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send the request. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final String? username = ref.watch(currentProfileProvider).valueOrNull?.username;
    return Scaffold(
      appBar: AppBar(title: const Text('Add a friend')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Find by username', style: text.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  onSubmitted: _search,
                  decoration: const InputDecoration(
                    labelText: 'Exact username',
                    prefixText: '@',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Search'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error)),
          if (_searched && _found == null && _error == null)
            Text(
              'No one found with that exact username. Check the spelling, or ask your friend for their QR code.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (_found != null) _ResultCard(user: _found!, relation: _relation, onAdd: _sendRequest),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan a QR code'),
            onPressed: _scan,
          ),
          const SizedBox(height: 16),
          if (username != null && username.isNotEmpty)
            MyQrCard(username: username)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Pick a username in your profile to get your own QR code and invite link.',
                  style: text.bodyMedium,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'People can only find you by your exact username. Photos are shared with accepted friends only.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.user, required this.relation, required this.onAdd});

  final FriendUser user;
  final FriendRelation relation;
  final Future<void> Function(FriendUser) onAdd;

  @override
  Widget build(BuildContext context) {
    final label = switch (relation) {
      FriendRelation.friends => 'Already friends',
      FriendRelation.requestSent => 'Request sent',
      FriendRelation.requestReceived => 'Check your requests',
      FriendRelation.none => null,
    };
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        leading: FriendAvatar(user: user),
        title: Text(user.name),
        subtitle: Text('@${user.username}'),
        trailing: label == null
            ? FilledButton(onPressed: () => onAdd(user), child: const Text('Add'))
            : Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
