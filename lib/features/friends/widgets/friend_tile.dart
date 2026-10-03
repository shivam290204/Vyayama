import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/widgets/friend_avatar.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_badge.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One row of the friends list: avatar, name, status chip, streak, camera.
class FriendTile extends ConsumerWidget {
  const FriendTile({super.key, required this.entry});

  final FriendWithStreak entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(currentUserIdProvider);
    final now = ref.watch(clockProvider)().toUtc();
    final streak = entry.streak;
    final status = SnapStreakCalculator.statusFor(streak, me, now);
    final count =
        streak == null ? 0 : SnapStreakCalculator.effectiveCurrent(streak, now);
    final user = entry.user;
    return InkWell(
      onTap: () => context.push(AppRoutes.friendDetailPath(user.id)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FriendAvatar(user: user),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('@${user.username}',
                        style: text.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    StreakStatusChip(status: status),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StreakBadge(count: count, atRisk: status == PairStatus.atRisk),
              IconButton(
                tooltip: 'Send ${user.name} a snap',
                icon: const Icon(Icons.photo_camera_outlined),
                onPressed: () =>
                    context.push('${AppRoutes.snapsCamera}?to=${user.id}'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
