import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_badge.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_countdown.dart';
import 'package:fitbuddy/features/snap_streaks/widgets/streak_status_chip.dart';
import 'package:flutter/material.dart';

/// Larger card explaining the pair state, with countdown while a day is open.
class StreakStatusPanel extends StatelessWidget {
  const StreakStatusPanel({
    super.key,
    required this.streak,
    required this.myId,
    required this.friendName,
    required this.nowUtc,
    this.clock = DateTime.now,
  });

  final SnapStreak? streak;
  final String myId;
  final String friendName;
  final DateTime nowUtc;
  final DateTime Function() clock;

  (String, String) _copy(PairStatus s) => switch (s) {
        PairStatus.none => (
            'No streak yet',
            'Send $friendName a snap to start one.'
          ),
        PairStatus.waitingOnFriend => (
            'Waiting for $friendName',
            'You sent yours. When they send theirs, the streak grows.'
          ),
        PairStatus.yourTurn => (
            '$friendName sent theirs',
            'Send yours to keep the 🔥 going.'
          ),
        PairStatus.completedToday => (
            'Done for today!',
            'Both snaps are in. See you tomorrow.'
          ),
        PairStatus.atRisk => (
            'Streak at risk ⏳',
            'Send your snap before the day ends to keep it alive.'
          ),
        PairStatus.broken => (
            'Streak ended',
            'No worries. Start a fresh one today!'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final status = SnapStreakCalculator.statusFor(streak, myId, nowUtc);
    final count =
        streak == null ? 0 : SnapStreakCalculator.effectiveCurrent(streak!, nowUtc);
    final (title, subtitle) = _copy(status);
    final showCountdown = streak != null &&
        status != PairStatus.completedToday &&
        status != PairStatus.broken &&
        status != PairStatus.none;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            StreakBadge(
              count: count,
              atRisk: status == PairStatus.atRisk,
              large: true,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: text.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StreakStatusChip(status: status),
                      if (showCountdown)
                        StreakCountdown(timezone: streak!.timezone, clock: clock),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
