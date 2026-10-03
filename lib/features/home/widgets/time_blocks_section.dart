import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/schedule/block_actions.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
import 'package:fitbuddy/features/schedule/widgets/time_block_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Today's time-block cards (workout, meal, medicine, sleep) with status.
/// Handles loading, empty and error states.
class TimeBlocksSection extends ConsumerWidget {
  /// Creates the section.
  const TimeBlocksSection({super.key, this.maxItems = 6});

  /// Maximum number of cards shown on Home.
  final int maxItems;

  /// Picks up to [maxItems] entries, starting just before the first block
  /// that is still upcoming or missed.
  List<TimeBlockEntry> visible(List<TimeBlockEntry> entries) {
    if (entries.length <= maxItems) return entries;
    final firstOpen = entries.indexWhere(
      (e) => e.status == BlockStatus.upcoming || e.status == BlockStatus.missed,
    );
    final anchor = firstOpen == -1 ? entries.length - 1 : firstOpen;
    final start = (anchor - 1).clamp(0, entries.length - maxItems).toInt();
    return entries.sublist(start, start + maxItems);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayScheduleProvider);
    return today.when(
      loading: () => const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.error_outline, semanticLabel: 'Error'),
          title: const Text("Couldn't load today's plan"),
          trailing: TextButton(
            onPressed: () {
              ref
                ..invalidate(scheduleBlocksProvider)
                ..invalidate(todayCompletionsProvider);
            },
            child: const Text('Retry'),
          ),
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('Nothing planned today'),
              subtitle: const Text('Add a workout, meal or reminder.'),
              trailing: TextButton(
                onPressed: () => context.push(AppRoutes.schedule),
                child: const Text('Plan'),
              ),
            ),
          );
        }
        final shown = visible(entries);
        return Column(
          children: [
            for (final e in shown) ...[
              TimeBlockCard(
                block: e.block,
                status: e.status,
                compact: true,
                onTap: () => context.push(AppRoutes.schedule),
                onToggleDone: e.block.type.needsCompletion
                    ? () => toggleBlockDone(ref, e)
                    : null,
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(AppRoutes.schedule),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  entries.length > shown.length
                      ? 'See all ${entries.length} blocks'
                      : 'Open schedule',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
