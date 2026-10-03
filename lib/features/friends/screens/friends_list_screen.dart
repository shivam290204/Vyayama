import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/friends/widgets/friend_tile.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            tooltip: 'Friends Feed',
            icon: const Icon(Icons.dynamic_feed_outlined),
            onPressed: () => context.push(AppRoutes.feed),
          ),
          IconButton(
            tooltip: 'Snap inbox',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.push(AppRoutes.snapsInbox),
          ),
          IconButton(
            tooltip: requests > 0
                ? 'Friend requests, $requests waiting'
                : 'Friend requests',
            icon: Badge(
              isLabelVisible: requests > 0,
              label: Text('$requests'),
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () => context.push(AppRoutes.friendsRequests),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.friendsAdd),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add friend'),
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
