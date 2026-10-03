import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/async_body.dart';
import 'package:fitbuddy/features/friends/widgets/friend_avatar.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_history_strip.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum _Action { remove, block, report }

/// `/friends/:id`: pair streak status, history and safety actions.
class FriendDetailScreen extends ConsumerWidget {
  const FriendDetailScreen({super.key, required this.friendId});

  final String friendId;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<String?> _pickReason(BuildContext context) {
    const reasons = [
      'Inappropriate photos',
      'Harassment or bullying',
      'Spam or fake account',
      'Something else',
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Why are you reporting?'),
        children: [
          for (final r in reasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(r),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _Action action,
    FriendUser user,
  ) async {
    final repo = ref.read(friendRepositoryProvider);
    String message;
    switch (action) {
      case _Action.remove:
        if (!await _confirm(context,
            title: 'Remove ${user.name}?',
            message: 'Your streak with ${user.name} will end.',
            action: 'Remove')) {
          return;
        }
        await repo.removeFriend(user.id);
        message = '${user.name} was removed';
      case _Action.block:
        if (!await _confirm(context,
            title: 'Block ${user.name}?',
            message: 'They will not be able to find you or send you snaps.',
            action: 'Block')) {
          return;
        }
        await repo.blockUser(user.id);
        message = '${user.name} is blocked';
      case _Action.report:
        final reason = await _pickReason(context);
        if (reason == null) return;
        await repo.reportUser(user.id, reason);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks. We will take a look.')),
          );
        }
        return;
    }
    invalidateFriendData(ref);
    if (context.mounted) {
      context.go(AppRoutes.friends);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(friendDetailProvider(friendId));
    final me = ref.watch(currentUserIdProvider);
    final clock = ref.watch(clockProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend'),
        actions: [
          if (value.valueOrNull != null)
            PopupMenuButton<_Action>(
              tooltip: 'More options',
              onSelected: (a) => _handle(context, ref, a, value.value!.user),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _Action.remove, child: Text('Remove friend')),
                PopupMenuItem(value: _Action.block, child: Text('Block')),
                PopupMenuItem(value: _Action.report, child: Text('Report')),
              ],
            ),
        ],
      ),
      body: AsyncBody<FriendWithStreak?>(
        value: value,
        onRetry: () => ref.invalidate(friendsWithStreakProvider),
        isEmpty: (d) => d == null,
        emptyIcon: Icons.person_off_outlined,
        emptyTitle: 'Friend not found',
        emptyMessage: 'They may have been removed.',
        emptyActionLabel: 'Back to friends',
        onEmptyAction: () => context.go(AppRoutes.friends),
        data: (entry) {
          final e = entry!;
          final now = clock().toUtc();
          final streak = e.streak;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: FriendAvatar(user: e.user, radius: 44)),
              const SizedBox(height: 12),
              Text(e.user.name, style: text.headlineSmall, textAlign: TextAlign.center),
              Text('@${e.user.username}',
                  style: text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              StreakStatusPanel(
                streak: streak,
                myId: me,
                friendName: e.user.name,
                nowUtc: now,
                clock: clock,
              ),
              const SizedBox(height: 24),
              Text('Streak history', style: text.titleMedium),
              const SizedBox(height: 12),
              if (streak != null) ...[
                StreakHistoryStrip(streak: streak, nowUtc: now),
                const SizedBox(height: 8),
                Text('Longest streak: ${streak.longest} days', style: text.bodyMedium),
              ] else
                Text('Send a first snap to start your streak.',
                    style: text.bodyMedium),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text('Send ${e.user.name} a snap'),
                onPressed: () =>
                    context.push('${AppRoutes.snapsCamera}?to=${e.user.id}'),
              ),
            ],
          );
        },
      ),
    );
  }
}
