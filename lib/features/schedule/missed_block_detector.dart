import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Pure Dart rules for deciding which blocks are upcoming, done or missed.
class MissedBlockDetector {
  /// Creates the detector.
  ///
  /// A block is missed [graceMinutes] after its start time. A missed block
  /// counts as "missed right now" for the mascot for [recentWindowMinutes]
  /// after its start; missed workouts count for the rest of the day.
  const MissedBlockDetector({
    this.graceMinutes = 15,
    this.recentWindowMinutes = 240,
  });

  /// Minutes after the start time before a block counts as missed.
  final int graceMinutes;

  /// How long a missed non-workout block keeps the mascot sad.
  final int recentWindowMinutes;

  /// Whether [block] is active and repeats on the weekday of [day].
  bool isScheduledOn(TimeBlock block, DateTime day) =>
      block.isActive && block.daysOfWeek.contains(day.weekday);

  /// Minutes between the block's start and [now] (negative if not started).
  int minutesSinceStart(TimeBlock block, DateTime now) =>
      now.hour * 60 + now.minute - block.startMinutes;

  /// Status of [block] at [now], given today's [completion] if any.
  BlockStatus statusFor(
    TimeBlock block, {
    required DateTime now,
    BlockCompletion? completion,
  }) {
    if (completion != null) {
      return switch (completion.status) {
        CompletionStatus.done => BlockStatus.done,
        CompletionStatus.skipped => BlockStatus.skipped,
        CompletionStatus.missed => BlockStatus.missed,
      };
    }
    final since = minutesSinceStart(block, now);
    if (!block.type.needsCompletion) {
      return since >= 0 ? BlockStatus.passed : BlockStatus.upcoming;
    }
    return since >= graceMinutes ? BlockStatus.missed : BlockStatus.upcoming;
  }

  /// Whether a block with [status] should make the mascot sad at [now].
  bool countsAsMissedNow(TimeBlock block, BlockStatus status, DateTime now) {
    if (status != BlockStatus.missed || !block.type.needsCompletion) {
      return false;
    }
    if (block.type == BlockType.workout) return true;
    return minutesSinceStart(block, now) <= recentWindowMinutes;
  }

  /// Whether any block scheduled today is missed right now.
  ///
  /// Only completions dated today are considered.
  bool anyMissedNow({
    required Iterable<TimeBlock> blocks,
    required Iterable<BlockCompletion> completions,
    required DateTime now,
  }) {
    for (final block in blocks) {
      if (!isScheduledOn(block, now)) continue;
      final completion = completions
          .where((c) => c.blockId == block.id && isSameDay(c.date, now))
          .firstOrNull;
      final status = statusFor(block, now: now, completion: completion);
      if (countsAsMissedNow(block, status, now)) return true;
    }
    return false;
  }
}
