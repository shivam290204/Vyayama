import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/friends/widgets/friend_tile.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/friends`: friends with their pair streak and today's status.
class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    invalidateFriendData(ref);
    await ref.read(friendsWithStreakProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(friendsWithStreakProvider);
    final requests = ref.watch(incomingRequestCountProvider);
    final unviewedSnaps = ref.watch(unviewedSnapsCountProvider);
    final totalMessages = requests + unviewedSnaps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push(AppRoutes.friendsAdd),
          ),
          IconButton(
            tooltip: 'Friends Feed',
            icon: const Icon(Icons.dynamic_feed_outlined),
            onPressed: () => context.push(AppRoutes.feed),
          ),
          IconButton(
            tooltip: unviewedSnaps > 0
                ? 'Snap inbox ($unviewedSnaps new)'
                : 'Snap inbox',
            icon: Badge(
              isLabelVisible: unviewedSnaps > 0,
              label: Text('$unviewedSnaps'),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.inbox_outlined),
            ),
            onPressed: () => context.push(AppRoutes.snapsInbox),
          ),
          IconButton(
            tooltip: totalMessages > 0
                ? 'Messages ($totalMessages waiting)'
                : 'Messages',
            icon: Badge(
              isLabelVisible: totalMessages > 0,
              label: Text('$totalMessages'),
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () {
              if (requests > 0) {
                context.push(AppRoutes.friendsRequests);
              } else {
                context.push(AppRoutes.snapsInbox);
              }
            },
          ),
        ],
      ),
      body: AsyncBody<List<FriendWithStreak>>(
        value: value,
        onRetry: () => invalidateFriendData(ref),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.group_outlined,
        emptyTitle: 'No friends yet',
        emptyMessage:
            'Add a friend by their exact username or QR code. Snap streaks are more fun together!',
        emptyActionLabel: 'Add a friend',
        onEmptyAction: () => context.push(AppRoutes.friendsAdd),
        data: (list) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => FriendTile(entry: list[i]),
          ),
        ),
      ),
    );
  }
}
