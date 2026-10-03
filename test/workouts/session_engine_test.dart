import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final a = SessionItem(
    exercise: ex('a', 'legs', met: 5),
    prescription: pe('p1', 'a', sets: 2, reps: 10, rest: 30),
  );
  final b = SessionItem(
    exercise: ex('b', 'cardio', met: 8),
    prescription: pe('p2', 'b', sets: 1, duration: 20, rest: 10),
  );

  SessionState ticks(SessionState s, int n) {
    var out = s;
    for (var i = 0; i < n; i++) {
      out = SessionEngine.tick(out);
    }
    return out;
  }

  test('starts on the first set of the first exercise', () {
    final s = SessionEngine.start([a, b]);
    expect(s.phase, SessionPhase.work);
    expect(s.index, 0);
    expect(s.setIndex, 0);
  });

  test('an empty item list gives the empty state', () {
    expect(SessionEngine.start(const []).items, isEmpty);
  });

  test('completing a set starts rest, then the next set', () {
    var s = SessionEngine.completeSet(SessionEngine.start([a, b]));
    expect(s.phase, SessionPhase.rest);
    expect(s.secondsLeft, 30);
    expect(s.nextIndex, 0);
    expect(s.nextSet, 1);
    s = ticks(s, 30);
    expect(s.phase, SessionPhase.work);
    expect(s.setIndex, 1);
    expect(s.restSeconds, 30);
  });

  test('skipRest moves on immediately', () {
    var s = SessionEngine.completeSet(SessionEngine.start([a, b]));
    s = SessionEngine.skipRest(s);
    expect(s.phase, SessionPhase.work);
    expect(s.setIndex, 1);
  });

  test('addRestTime extends the rest countdown', () {
    var s = SessionEngine.completeSet(SessionEngine.start([a, b]));
    s = SessionEngine.addRestTime(s);
    expect(s.secondsLeft, 45);
  });

  test('timed exercises count down and complete on their own', () {
    var s = SessionEngine.start([a, b]);
    s = SessionEngine.completeSet(s); // a set 1 -> rest
    s = SessionEngine.skipRest(s);
    s = SessionEngine.completeSet(s); // a set 2 -> rest before b
    expect(s.nextIndex, 1);
    s = SessionEngine.skipRest(s);
    expect(s.current.timed, isTrue);
    expect(s.secondsLeft, 20);
    s = ticks(s, 20);
    expect(s.isFinished, isTrue);
  });

  test('pause stops the clock', () {
    var s = SessionEngine.start([a, b]);
    s = SessionEngine.togglePause(s);
    s = ticks(s, 5);
    expect(s.elapsedSeconds, 0);
    s = SessionEngine.togglePause(s);
    s = ticks(s, 5);
    expect(s.elapsedSeconds, 5);
  });

  test('next and previous move between exercises', () {
    var s = SessionEngine.start([a, b]);
    s = SessionEngine.next(s);
    expect(s.index, 1);
    s = SessionEngine.previous(s);
    expect(s.index, 0);
    s = SessionEngine.previous(s);
    expect(s.index, 0);
    s = SessionEngine.next(SessionEngine.next(s));
    expect(s.isFinished, isTrue);
  });

  test('summary reports completed exercises, minutes and calories', () {
    var s = SessionEngine.start([a, b]);
    s = ticks(s, 90);
    s = SessionEngine.completeSet(s);
    s = SessionEngine.skipRest(s);
    s = SessionEngine.completeSet(s);
    s = SessionEngine.finish(s);
    final summary = SessionEngine.summarize(s, 70);
    expect(summary.exercisesCompleted, 1);
    expect(summary.totalExercises, 2);
    expect(summary.durationMin, 2); // 90 s rounds to 2
    expect(summary.calories, greaterThan(0));
    expect(summary.completionRatio, 0.5);
  });
}
