import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/friend_avatar.dart';
import 'package:fitbuddy/features/friends/widgets/my_qr_card.dart';
import 'package:fitbuddy/features/friends/widgets/qr_scan_sheet.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/friends/add`: exact-username search, My QR code, QR scan, and deep link sharing.
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
    var q = (query ?? _controller.text).trim();
    if (q.startsWith('@')) {
      q = q.substring(1).trim();
    }
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    try {
      final repo = ref.read(friendRepositoryProvider);
      final user = await repo.findByIdentifier(q);
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
    final identifier = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const QrScanSheet(),
    );
    if (identifier == null || !mounted) return;
    context.push(AppRoutes.userProfilePath(identifier));
  }

  Future<void> _sendRequest(FriendUser user) async {
    try {
      await ref.read(friendRepositoryProvider).sendRequest(user.id);
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(userRelationProvider(user.id));
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
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final String? username = profile?.username;

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
                    labelText: 'Exact username or handle',
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
              'No athlete found with that exact username. Check the spelling, or ask your friend for their QR code.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (_found != null)
            _ResultCard(
              user: _found!,
              relation: _relation,
              onAdd: _sendRequest,
              isMe: _found!.id == ref.watch(currentUserIdProvider) ||
                  (username != null &&
                      username.toLowerCase() ==
                          _found!.username.toLowerCase()),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(color: const Color(0xFF14532D).withValues(alpha: 0.6)),
            ),
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF14532D)),
            label: const Text(
              'Scan a QR code',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF14532D),
              ),
            ),
            onPressed: _scan,
          ),
          const SizedBox(height: 20),
          if (profile != null) ...[
            if (username == null || username.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Set a username so friends can easily search you with @username.',
                        style: text.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.profileEdit),
                      child: const Text('Set handle'),
                    ),
                  ],
                ),
              ),
            MyQrCard(profile: profile),
          ] else ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'People can find you by your exact username or by scanning your permanent QR code. Workouts and photos are shared with accepted friends only.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.user,
    required this.relation,
    required this.onAdd,
    this.isMe = false,
  });

  final FriendUser user;
  final FriendRelation relation;
  final Future<void> Function(FriendUser) onAdd;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    if (isMe) {
      return Card(
        child: ListTile(
          minVerticalPadding: 12,
          leading: FriendAvatar(user: user),
          title: Text(user.name),
          subtitle: Text('@${user.username}'),
          trailing: Text(
            'This is you',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    final label = switch (relation) {
      FriendRelation.friends => 'Already friends',
      FriendRelation.requestSent => 'Request sent',
      FriendRelation.requestReceived => null,
      FriendRelation.none => null,
    };
    return Card(
      child: ListTile(
        onTap: () => context.push(AppRoutes.userProfilePath(user.id)),
        minVerticalPadding: 12,
        leading: FriendAvatar(user: user),
        title: Text(user.name),
        subtitle: Text(user.username.isNotEmpty ? '@${user.username}' : 'Athlete'),
        trailing: relation == FriendRelation.requestReceived
            ? OutlinedButton(
                onPressed: () => context.push(AppRoutes.friendsRequests),
                child: const Text('View request'),
              )
            : label == null
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14532D),
                    ),
                    onPressed: () => onAdd(user),
                    child: const Text('Add'),
                  )
                : Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}
