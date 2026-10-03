import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
import 'package:fitbuddy/features/schedule/widgets/block_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Marks [entry] done, or undoes it if it already is.
///
/// Finishing a workout block also tells the mascot (mock signal until the
/// real workout log is wired in). Undo clears the flag; with several workout
/// blocks in one day Antigravity should derive this from workout logs.
Future<void> toggleBlockDone(WidgetRef ref, TimeBlockEntry entry) async {
  final wasDone = entry.status == BlockStatus.done;
  await ref.read(todayCompletionsProvider.notifier).setStatus(
        entry.block.id,
        wasDone ? null : CompletionStatus.done,
      );
  if (entry.block.type == BlockType.workout) {
    final mascot = ref.read(mascotSignalsProvider.notifier);
    if (wasDone) {
      mascot.markWorkoutNotDone();
    } else {
      mascot.markWorkoutDone();
    }
  }
}

/// Opens the editor sheet and applies the result (save or delete).
///
/// Deleting shows a snackbar with Undo.
Future<void> editBlockFlow(
  BuildContext context,
  WidgetRef ref, {
  TimeBlock? existing,
}) async {
  final result = await showBlockEditorSheet(context, existing: existing);
  if (result == null || !context.mounted) return;
  final notifier = ref.read(scheduleBlocksProvider.notifier);
  switch (result) {
    case BlockSaved(:final block):
      await notifier.save(block);
    case BlockDeleted():
      if (existing == null) return;
      await notifier.remove(existing.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted "${existing.title}"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => notifier.save(existing),
            ),
          ),
        );
  }
}
