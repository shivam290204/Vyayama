import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/day_key.dart';

/// Storage for schedule blocks and their daily completions.
///
/// Antigravity will add a Supabase implementation later.
abstract class ScheduleRepository {
  /// All of the user's blocks.
  Future<List<TimeBlock>> fetchBlocks();

  /// Inserts (empty id) or updates a block and returns the saved row.
  Future<TimeBlock> upsertBlock(TimeBlock block);

  /// Deletes a block and its completions.
  Future<void> deleteBlock(String id);

  /// Completions recorded for [day].
  Future<List<BlockCompletion>> fetchCompletions(DateTime day);

  /// Sets the result of [blockId] on [day]. A null [status] clears it.
  Future<void> setCompletion({
    required String blockId,
    required DateTime day,
    required CompletionStatus? status,
  });
}

/// In-memory repository seeded with a sample day.
class MockScheduleRepository implements ScheduleRepository {
  /// Creates the mock. Pass [seed] or [completions] in tests.
  MockScheduleRepository({
    List<TimeBlock>? seed,
    List<BlockCompletion>? completions,
  })  : _blocks = List<TimeBlock>.of(seed ?? defaultSeed),
        _completions = List<BlockCompletion>.of(
          completions ?? const <BlockCompletion>[],
        );

  /// User id used by the mock.
  static const String mockUserId = 'mock-user';

  /// Sample day: wake, workout, meals, a reminder, bedtime.
  static const List<TimeBlock> defaultSeed = [
    TimeBlock(
      id: 'blk-1',
      userId: mockUserId,
      type: BlockType.wake,
      title: 'Wake up',
      startMinutes: 6 * 60 + 30,
    ),
    TimeBlock(
      id: 'blk-2',
      userId: mockUserId,
      type: BlockType.workout,
      title: 'Morning workout',
      startMinutes: 7 * 60,
    ),
    TimeBlock(
      id: 'blk-3',
      userId: mockUserId,
      type: BlockType.meal,
      title: 'Breakfast',
      startMinutes: 8 * 60 + 30,
    ),
    TimeBlock(
      id: 'blk-4',
      userId: mockUserId,
      type: BlockType.medicine,
      title: 'Morning medicine reminder',
      startMinutes: 9 * 60,
    ),
    TimeBlock(
      id: 'blk-5',
      userId: mockUserId,
      type: BlockType.meal,
      title: 'Lunch',
      startMinutes: 13 * 60,
    ),
    TimeBlock(
      id: 'blk-6',
      userId: mockUserId,
      type: BlockType.workout,
      title: 'Evening walk',
      startMinutes: 18 * 60 + 30,
    ),
    TimeBlock(
      id: 'blk-7',
      userId: mockUserId,
      type: BlockType.meal,
      title: 'Dinner',
      startMinutes: 20 * 60,
    ),
    TimeBlock(
      id: 'blk-8',
      userId: mockUserId,
      type: BlockType.sleep,
      title: 'Bedtime',
      startMinutes: 22 * 60 + 30,
    ),
  ];

  final List<TimeBlock> _blocks;
  final List<BlockCompletion> _completions;
  int _nextId = 100;

  @override
  Future<List<TimeBlock>> fetchBlocks() async =>
      List<TimeBlock>.unmodifiable(_blocks);

  @override
  Future<TimeBlock> upsertBlock(TimeBlock block) async {
    final id = block.id.isEmpty ? 'blk-${_nextId++}' : block.id;
    final saved = block.copyWith(
      id: id,
      userId: block.userId.isEmpty ? mockUserId : block.userId,
    );
    final index = _blocks.indexWhere((b) => b.id == id);
    if (index == -1) {
      _blocks.add(saved);
    } else {
      _blocks[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteBlock(String id) async {
    _blocks.removeWhere((b) => b.id == id);
    _completions.removeWhere((c) => c.blockId == id);
  }

  @override
  Future<List<BlockCompletion>> fetchCompletions(DateTime day) async =>
      List<BlockCompletion>.unmodifiable(
        _completions.where((c) => isSameDay(c.date, day)),
      );

  @override
  Future<void> setCompletion({
    required String blockId,
    required DateTime day,
    required CompletionStatus? status,
  }) async {
    _completions.removeWhere(
      (c) => c.blockId == blockId && isSameDay(c.date, day),
    );
    if (status != null) {
      _completions.add(
        BlockCompletion(
          id: 'cmp-${_nextId++}',
          blockId: blockId,
          userId: mockUserId,
          date: dayOnly(day),
          status: status,
        ),
      );
    }
  }
}
