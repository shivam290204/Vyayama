import 'package:fitbuddy/features/schedule/block_actions.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
import 'package:fitbuddy/features/schedule/widgets/block_type_ui.dart';
import 'package:fitbuddy/features/schedule/widgets/schedule_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Day timeline of time blocks with add, edit and mark-done actions.
class ScheduleScreen extends ConsumerWidget {
  /// Creates the screen.
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayScheduleProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editBlockFlow(context, ref),
        icon: const Icon(Icons.add, semanticLabel: 'Add block'),
        label: const Text('Add block'),
      ),
      body: today.when(
        loading: () => Center(
          child: Semantics(
            label: 'Loading schedule',
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (_, __) => _ErrorView(
          onRetry: () {
            ref.invalidate(scheduleBlocksProvider);
            ref.invalidate(todayCompletionsProvider);
          },
        ),
        data: (entries) => _Body(entries: entries),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.entries});

  final List<TimeBlockEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final others = ref.watch(otherBlocksProvider);
    final day = ref.watch(todayProvider);
    final tracked = entries.where((e) => e.block.type.needsCompletion).toList();
    final done = tracked.where((e) => e.status == BlockStatus.done).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text('Today', style: text.headlineSmall),
        Text(formatLongDate(day), style: text.bodyMedium),
        const SizedBox(height: 12),
        if (tracked.isNotEmpty) ...[
          Semantics(
            label: 'Progress today',
            value: '$done of ${tracked.length} done',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: done / tracked.length,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('$done of ${tracked.length} done', style: text.bodySmall),
          const SizedBox(height: 16),
        ],
        if (entries.isEmpty)
          const _EmptyView()
        else
          ScheduleTimeline(
            entries: entries,
            onTap: (e) => editBlockFlow(context, ref, existing: e.block),
            onToggleDone: (e) => toggleBlockDone(ref, e),
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Not scheduled today', style: text.titleMedium),
          const SizedBox(height: 4),
          for (final b in others)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(b.type.icon, semanticLabel: b.type.label),
              title: Text(b.title),
              subtitle: Text(b.isActive ? 'Other days' : 'Inactive'),
              onTap: () => editBlockFlow(context, ref, existing: b),
            ),
        ],
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
            semanticLabel: 'Empty schedule',
          ),
          const SizedBox(height: 12),
          Text('Nothing planned today', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Add a workout, meal or reminder to get started.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
              semanticLabel: 'Error',
            ),
            const SizedBox(height: 12),
            Text(
              "We couldn't load your schedule.",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
