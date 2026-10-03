import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/widgets/time_block_card.dart';
import 'package:flutter/material.dart';

/// Vertical day timeline: time on the left, a rail, and the block cards.
///
/// The first upcoming block gets a highlighted dot.
class ScheduleTimeline extends StatelessWidget {
  /// Creates the timeline for [entries] (already sorted by time).
  const ScheduleTimeline({
    super.key,
    required this.entries,
    required this.onTap,
    required this.onToggleDone,
  });

  /// Blocks scheduled today.
  final List<TimeBlockEntry> entries;

  /// Called when a card is tapped.
  final ValueChanged<TimeBlockEntry> onTap;

  /// Called when a card's done button is pressed.
  final ValueChanged<TimeBlockEntry> onToggleDone;

  @override
  Widget build(BuildContext context) {
    final nextIndex =
        entries.indexWhere((e) => e.status == BlockStatus.upcoming);
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          _TimelineRow(
            entry: entries[i],
            isNext: i == nextIndex,
            isLast: i == entries.length - 1,
            onTap: () => onTap(entries[i]),
            onToggleDone: () => onToggleDone(entries[i]),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isNext,
    required this.isLast,
    required this.onTap,
    required this.onToggleDone,
  });

  final TimeBlockEntry entry;
  final bool isNext;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = entry.block;
    final time = TimeOfDay(
      hour: block.startMinutes ~/ 60,
      minute: block.startMinutes % 60,
    ).format(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    time,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: isNext ? 14 : 10,
                  height: isNext ? 14 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNext ? scheme.primary : scheme.outline,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TimeBlockCard(
                block: block,
                status: entry.status,
                onTap: onTap,
                onToggleDone: onToggleDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
