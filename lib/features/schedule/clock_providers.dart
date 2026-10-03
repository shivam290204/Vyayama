import 'package:fitbuddy/features/schedule/day_key.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of "now". Override in tests to control time.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Emits the current time immediately and then once a minute.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock();
  yield* Stream<DateTime>.periodic(const Duration(minutes: 1), (_) => clock());
});

/// Today's local calendar day. Only notifies when the day changes.
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(nowProvider).asData?.value ?? ref.read(clockProvider)();
  return dayOnly(now);
});
