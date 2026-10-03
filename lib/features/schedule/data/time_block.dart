import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter/foundation.dart';

/// Kind of schedule block (column `schedule_blocks.type`).
enum BlockType {
  /// A workout session.
  workout,

  /// A meal reminder.
  meal,

  /// A medicine reminder (name and time only, never dosage).
  medicine,

  /// Bedtime.
  sleep,

  /// Wake-up time.
  wake,

  /// Anything else.
  custom;

  /// Parses a database value, defaulting to [custom].
  static BlockType parse(String? value) => BlockType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => BlockType.custom,
      );

  /// Whether the user is expected to mark this block done.
  ///
  /// Sleep and wake blocks are reminders only and never count as missed.
  bool get needsCompletion => this != sleep && this != wake;
}

/// Stored completion state (column `block_completions.status`).
enum CompletionStatus {
  /// Finished.
  done,

  /// Recorded as missed.
  missed,

  /// Deliberately skipped.
  skipped;

  /// Parses a database value, defaulting to [done].
  static CompletionStatus parse(String? value) =>
      CompletionStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => CompletionStatus.done,
      );
}

/// How a block looks today.
enum BlockStatus {
  /// Its time has not come yet (or is within the grace period).
  upcoming,

  /// The user finished it.
  done,

  /// Its time passed without completion.
  missed,

  /// The user skipped it on purpose.
  skipped,

  /// A sleep or wake block whose time has passed.
  passed,
}

/// A repeating daily time block. Mirrors table `schedule_blocks`.
@immutable
class TimeBlock {
  /// Creates a block. An empty [id] means "not saved yet".
  const TimeBlock({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.startMinutes,
    this.daysOfWeek = allDays,
    this.isActive = true,
  });

  /// Every day of the week, 1 = Monday ... 7 = Sunday (`DateTime.weekday`).
  static const List<int> allDays = [1, 2, 3, 4, 5, 6, 7];

  /// Parses a row of `schedule_blocks`.
  factory TimeBlock.fromJson(Map<String, dynamic> json) {
    final days = (json['days_of_week'] as List<dynamic>?)?.cast<int>() ??
        allDays;
    return TimeBlock(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      type: BlockType.parse(json['type'] as String?),
      title: (json['title'] as String?) ?? '',
      startMinutes: parseTime(json['start_time'] as String),
      daysOfWeek: List<int>.unmodifiable([...days]..sort()),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  /// Converts `HH:mm` or `HH:mm:ss` into minutes after midnight.
  static int parseTime(String value) {
    final p = value.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  /// Converts minutes after midnight into `HH:mm:00`.
  static String formatTime(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  /// Row id, or empty when new.
  final String id;

  /// Owner (`user_id`).
  final String userId;

  /// Kind of block.
  final BlockType type;

  /// Display title.
  final String title;

  /// Start time as minutes after midnight (`start_time`).
  final int startMinutes;

  /// Days it repeats on, 1 = Monday ... 7 = Sunday (`days_of_week`).
  final List<int> daysOfWeek;

  /// Inactive blocks are hidden from today's plan (`is_active`).
  final bool isActive;

  /// Returns a copy with the given fields replaced.
  TimeBlock copyWith({
    String? id,
    String? userId,
    BlockType? type,
    String? title,
    int? startMinutes,
    List<int>? daysOfWeek,
    bool? isActive,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      startMinutes: startMinutes ?? this.startMinutes,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Converts to a `schedule_blocks` row (id omitted when new).
  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        if (userId.isNotEmpty) 'user_id': userId,
        'type': type.name,
        'title': title,
        'start_time': formatTime(startMinutes),
        'days_of_week': daysOfWeek,
        'is_active': isActive,
      };
}

/// One day's result for one block. Mirrors table `block_completions`.
@immutable
class BlockCompletion {
  /// Creates a completion.
  const BlockCompletion({
    required this.id,
    required this.blockId,
    required this.userId,
    required this.date,
    required this.status,
  });

  /// Parses a row of `block_completions`.
  factory BlockCompletion.fromJson(Map<String, dynamic> json) {
    return BlockCompletion(
      id: json['id'] as String,
      blockId: json['block_id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      date: parseDayKey(json['date'] as String),
      status: CompletionStatus.parse(json['status'] as String?),
    );
  }

  /// Row id.
  final String id;

  /// Block this belongs to (`block_id`).
  final String blockId;

  /// Owner (`user_id`).
  final String userId;

  /// Calendar day (`date`).
  final DateTime date;

  /// Result (`status`).
  final CompletionStatus status;

  /// Converts to a `block_completions` row.
  Map<String, dynamic> toJson() => {
        'id': id,
        'block_id': blockId,
        'user_id': userId,
        'date': dayKey(date),
        'status': status.name,
      };
}

/// A block together with its status today.
@immutable
class TimeBlockEntry {
  /// Creates an entry.
  const TimeBlockEntry({required this.block, required this.status});

  /// The block.
  final TimeBlock block;

  /// Status today.
  final BlockStatus status;
}
