import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/widgets/friend_avatar.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Checklist of friends with their streak counts.
class RecipientPicker extends ConsumerWidget {
  const RecipientPicker({super.key, required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsWithStreakProvider);
    final now = ref.watch(clockProvider)().toUtc();
    return friends.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Could not load your friends. Pull to refresh on the Friends tab.'),
      ),
      data: (list) => list.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add a friend first to send snaps. You can still post to the feed.'),
            )
          : Column(
              children: [
                for (final f in list) _Row(
                  entry: f,
                  checked: selected.contains(f.user.id),
                  count: f.streak == null
                      ? 0
                      : SnapStreakCalculator.effectiveCurrent(f.streak!, now),
                  onToggle: () => onToggle(f.user.id),
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.entry,
    required this.checked,
    required this.count,
    required this.onToggle,
  });

  final FriendWithStreak entry;
  final bool checked;
  final int count;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: checked,
      onChanged: (_) => onToggle(),
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: FriendAvatar(user: entry.user, radius: 20),
      title: Text(entry.user.name),
      subtitle: StreakBadge(count: count),
    );
  }
}
