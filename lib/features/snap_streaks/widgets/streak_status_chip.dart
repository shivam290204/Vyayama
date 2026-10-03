import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:flutter/material.dart';

/// Short, friendly label for each [PairStatus].
String pairStatusLabel(PairStatus status) => switch (status) {
      PairStatus.none => 'Start a streak',
      PairStatus.waitingOnFriend => 'Waiting for them',
      PairStatus.yourTurn => 'Your turn',
      PairStatus.completedToday => 'Done today',
      PairStatus.atRisk => 'At risk ⏳',
      PairStatus.broken => 'Streak ended',
    };

/// Small coloured chip describing today's state of a pair streak.
class StreakStatusChip extends StatelessWidget {
  const StreakStatusChip({super.key, required this.status});

  final PairStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      PairStatus.yourTurn => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PairStatus.waitingOnFriend =>
        (scheme.secondaryContainer, scheme.onSecondaryContainer),
      PairStatus.completedToday =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      PairStatus.atRisk => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Semantics(
      container: true,
      label: 'Streak status: ${pairStatusLabel(status)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          pairStatusLabel(status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
        ),
      ),
    );
  }
}
