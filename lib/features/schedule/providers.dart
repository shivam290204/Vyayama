import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/schedule/data/schedule_repository.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/missed_block_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared detector with the default rules.
const MissedBlockDetector missedBlockDetector = MissedBlockDetector();

/// Schedule storage. Antigravity swaps in the Supabase implementation here.
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => MockScheduleRepository(),
);

/// All of the user's blocks, with save and remove actions.
class ScheduleBlocksNotifier extends AsyncNotifier<List<TimeBlock>> {
  @override
  Future<List<TimeBlock>> build() =>
      ref.watch(scheduleRepositoryProvider).fetchBlocks();

  /// Creates or updates [block].
  Future<void> save(TimeBlock block) async {
    final repo = ref.read(scheduleRepositoryProvider);
    await repo.upsertBlock(block);
    state = AsyncData(await repo.fetchBlocks());
  }

  /// Deletes the block with [id].
  Future<void> remove(String id) async {
    final repo = ref.read(scheduleRepositoryProvider);
    await repo.deleteBlock(id);
    state = AsyncData(await repo.fetchBlocks());
  }
}

/// All blocks.
final scheduleBlocksProvider =
    AsyncNotifierProvider<ScheduleBlocksNotifier, List<TimeBlock>>(
  ScheduleBlocksNotifier.new,
);

/// Today's completions, reloaded when the day changes.
class TodayCompletionsNotifier extends AsyncNotifier<List<BlockCompletion>> {
  @override
  Future<List<BlockCompletion>> build() {
    final day = ref.watch(todayProvider);
    return ref.watch(scheduleRepositoryProvider).fetchCompletions(day);
  }

  /// Sets today's result for [blockId]. A null [status] clears it.
  Future<void> setStatus(String blockId, CompletionStatus? status) async {
    final repo = ref.read(scheduleRepositoryProvider);
    final day = ref.read(todayProvider);
    await repo.setCompletion(blockId: blockId, day: day, status: status);
    state = AsyncData(await repo.fetchCompletions(day));
  }
}

/// Today's completions.
final todayCompletionsProvider =
    AsyncNotifierProvider<TodayCompletionsNotifier, List<BlockCompletion>>(
  TodayCompletionsNotifier.new,
);

/// Blocks scheduled today with their status, sorted by start time.
final todayScheduleProvider =
    Provider<AsyncValue<List<TimeBlockEntry>>>((ref) {
  final blocksAsync = ref.watch(scheduleBlocksProvider);
  final completionsAsync = ref.watch(todayCompletionsProvider);
  final now = ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();

  if (blocksAsync.hasError) {
    return AsyncValue.error(
      blocksAsync.error!,
      blocksAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (completionsAsync.hasError) {
    return AsyncValue.error(
      completionsAsync.error!,
      completionsAsync.stackTrace ?? StackTrace.current,
    );
  }
  final blocks = blocksAsync.asData?.value;
  final completions = completionsAsync.asData?.value;
  if (blocks == null || completions == null) return const AsyncValue.loading();

  final entries = <TimeBlockEntry>[
    for (final block in blocks)
      if (missedBlockDetector.isScheduledOn(block, now))
        TimeBlockEntry(
          block: block,
          status: missedBlockDetector.statusFor(
            block,
            now: now,
            completion: completions
                .where((c) => c.blockId == block.id)
                .firstOrNull,
          ),
        ),
  ]..sort((a, b) => a.block.startMinutes.compareTo(b.block.startMinutes));
  return AsyncValue.data(entries);
});

/// Blocks that do not run today (inactive or other weekdays).
final otherBlocksProvider = Provider<List<TimeBlock>>((ref) {
  final blocks =
      ref.watch(scheduleBlocksProvider).asData?.value ?? const <TimeBlock>[];
  final today = ref.watch(todayProvider);
  return [
    for (final b in blocks)
      if (!missedBlockDetector.isScheduledOn(b, today)) b,
  ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
});

/// True when a block was just missed. Feeds the mascot's `missedBlockNow`.
final missedBlockNowProvider = Provider<bool>((ref) {
  final entries =
      ref.watch(todayScheduleProvider).asData?.value ?? const <TimeBlockEntry>[];
  final now = ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();
  return entries.any(
    (e) => missedBlockDetector.countsAsMissedNow(e.block, e.status, now),
  );
});
