import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/friends/widgets/friend_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/friends/requests`: incoming and outgoing requests.
class FriendRequestsScreen extends ConsumerWidget {
  const FriendRequestsScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      invalidateFriendData(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not work. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(friendRepositoryProvider);
    final value = ref.watch(friendRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(friendRequestsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(friendRequestsProvider),
        child: AsyncBody<List<FriendRequest>>(
          value: value,
          onRetry: () => ref.invalidate(friendRequestsProvider),
          isEmpty: (d) => d.isEmpty,
          emptyIcon: Icons.mark_email_read_outlined,
          emptyTitle: 'No pending requests',
          emptyMessage: 'New requests will show up here.\nPull down to refresh.',
          data: (list) {
            final incoming = list.where((r) => r.incoming).toList();
            final outgoing = list.where((r) => !r.incoming).toList();
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (incoming.isNotEmpty) const _Header('Wants to be your friend'),
                for (final r in incoming)
                  _RequestTile(
                    request: r,
                    actions: [
                      TextButton(
                        onPressed: () => _run(context, ref,
                            () => repo.declineRequest(r.friendship.id), 'Request declined'),
                        child: const Text('Decline'),
                      ),
                      FilledButton(
                        onPressed: () {
                          final rawName = r.user.name.trim();
                          final rawUname = r.user.username.trim();
                          final name = (rawName.isNotEmpty &&
                                  rawName != 'Pending Friend' &&
                                  rawName != 'Athlete')
                              ? rawName
                              : (rawUname.isNotEmpty ? rawUname : 'Friend');
                          _run(
                            context,
                            ref,
                            () => repo.acceptRequest(r.friendship.id),
                            'You and $name are friends 🔥',
                          );
                        },
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                if (outgoing.isNotEmpty) const _Header('Waiting for a reply'),
                for (final r in outgoing)
                  _RequestTile(
                    request: r,
                    actions: [
                      TextButton(
                        onPressed: () => _run(context, ref,
                            () => repo.cancelRequest(r.friendship.id), 'Request cancelled'),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _RequestTile extends ConsumerStatefulWidget {
  const _RequestTile({required this.request, required this.actions});

  final FriendRequest request;
  final List<Widget> actions;

  @override
  ConsumerState<_RequestTile> createState() => _RequestTileState();
}

class _RequestTileState extends ConsumerState<_RequestTile> {
  FriendUser? _resolvedUser;

  @override
  void initState() {
    super.initState();
    _resolvedUser = widget.request.user;
    _resolveUserIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _RequestTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.user.id != widget.request.user.id ||
        oldWidget.request.user.name != widget.request.user.name) {
      _resolvedUser = widget.request.user;
      _resolveUserIfNeeded();
    }
  }

  void _resolveUserIfNeeded() {
    final cur = _resolvedUser ?? widget.request.user;
    final isGeneric = cur.name == 'Friend' ||
        cur.name == 'Athlete' ||
        cur.name == 'Pending Friend' ||
        cur.name.trim().isEmpty;
    if (isGeneric && cur.username.isEmpty) {
      ref.read(friendRepositoryProvider).getUser(cur.id).then((fetched) {
        if (mounted &&
            fetched != null &&
            (fetched.username.isNotEmpty || fetched.name != 'Friend')) {
          setState(() {
            _resolvedUser = fetched;
          });
        }
      }).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = _resolvedUser ?? widget.request.user;
    final rawName = user.name.trim();
    final rawUname = user.username.trim();
    final displayName = (rawName.isNotEmpty &&
            rawName != 'Pending Friend' &&
            rawName != 'Athlete' &&
            rawName != 'Friend')
        ? rawName
        : (rawUname.isNotEmpty
            ? rawUname
            : (rawName.isNotEmpty ? rawName : 'Friend'));

    final subtitleText = widget.request.incoming
        ? (rawUname.isNotEmpty
            ? '@$rawUname · sent you a request'
            : 'sent you a friend request')
        : (rawUname.isNotEmpty ? '@$rawUname' : 'Friend request pending');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FriendAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(subtitleText, style: text.bodySmall),
              ],
            ),
          ),
          Wrap(spacing: 4, children: widget.actions),
        ],
      ),
    );
  }
}
