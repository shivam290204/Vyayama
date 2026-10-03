import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/widgets/snap_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/feed`: 24-hour Friends Feed posts grouped by friend.
class FriendsFeedScreen extends ConsumerWidget {
  const FriendsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(feedProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Friends Feed')),
      body: AsyncBody<List<ReceivedSnap>>(
        value: value,
        onRetry: () => ref.invalidate(feedProvider),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.dynamic_feed_outlined,
        emptyTitle: 'Nothing posted today',
        emptyMessage: 'Posts from friends appear here for 24 hours.',
        emptyActionLabel: 'Post a snap',
        onEmptyAction: () => context.push(AppRoutes.snapsCamera),
        data: (list) {
          final groups = <String, List<ReceivedSnap>>{};
          for (final s in list) {
            groups.putIfAbsent(s.snap.senderId, () => []).add(s);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedProvider);
              await ref.read(feedProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final entry in groups.values) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      '${entry.first.senderName} · ${entry.length} post${entry.length == 1 ? '' : 's'}',
                      style: text.titleMedium,
                    ),
                  ),
                  SizedBox(
                    height: 128,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entry.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SnapThumb(item: entry[i]),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
