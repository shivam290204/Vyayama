import 'dart:math' as math;

import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/calorie_helper.dart';
import 'package:flutter/foundation.dart';

/// Where the guided session is.
enum SessionPhase { work, rest, finished }

/// An exercise resolved together with its prescription.
@immutable
class SessionItem {
  const SessionItem({required this.exercise, required this.prescription});

  final Exercise exercise;
  final PlanExercise prescription;

  int get sets => prescription.setCount;
  bool get timed => prescription.isTimed;
  int get restSec => prescription.restSec;
}

/// Result shown on the finish screen and saved to `workout_logs`.
@immutable
class SessionSummary {
  const SessionSummary({
    required this.durationSeconds,
    required this.durationMin,
    required this.calories,
    required this.exercisesCompleted,
    required this.totalExercises,
  });

  final int durationSeconds;
  final int durationMin;
  final int calories;
  final int exercisesCompleted;
  final int totalExercises;

  double get completionRatio =>
      totalExercises == 0 ? 0 : exercisesCompleted / totalExercises;
}

/// Immutable state of a guided session.
@immutable
class SessionState {
  const SessionState({
    required this.items,
    this.index = 0,
    this.setIndex = 0,
    this.phase = SessionPhase.work,
    this.secondsLeft = 0,
    this.paused = false,
    this.elapsedSeconds = 0,
    this.restSeconds = 0,
    this.workSeconds = const <int>[],
    this.setsDone = const <int>[],
    this.nextIndex = 0,
    this.nextSet = 0,
    this.summary,
  });

  /// "Not started" state.
  const SessionState.empty()
      : this(items: const <SessionItem>[], phase: SessionPhase.finished);

  final List<SessionItem> items;
  final int index;
  final int setIndex;
  final SessionPhase phase;

  /// Countdown for a timed set, or for the rest period.
  final int secondsLeft;
  final bool paused;
  final int elapsedSeconds;
  final int restSeconds;

  /// Seconds spent working on each item (used for calories).
  final List<int> workSeconds;

  /// Sets completed per item.
  final List<int> setsDone;

  /// During rest: the exercise and set that come next.
  final int nextIndex;
  final int nextSet;
  final SessionSummary? summary;

  SessionItem get current => items[index];
  bool get isFinished => phase == SessionPhase.finished;
  bool get isRest => phase == SessionPhase.rest;

  /// The exercise the user is on, or about to start during rest.
  int get displayIndex => isRest ? nextIndex : index;

  /// Fraction of all sets completed, 0 to 1.
  double get progress {
    if (items.isEmpty) return 0;
    final total = items.fold<int>(0, (s, i) => s + i.sets);
    if (total == 0) return 0;
    final done = setsDone.fold<int>(0, (s, d) => s + d);
    return math.min(1.0, done / total);
  }

  SessionState copyWith({
    int? index,
    int? setIndex,
    SessionPhase? phase,
    int? secondsLeft,
    bool? paused,
    int? elapsedSeconds,
    int? restSeconds,
    List<int>? workSeconds,
    List<int>? setsDone,
    int? nextIndex,
    int? nextSet,
    SessionSummary? summary,
  }) {
    return SessionState(
      items: items,
      index: index ?? this.index,
      setIndex: setIndex ?? this.setIndex,
      phase: phase ?? this.phase,
      secondsLeft: secondsLeft ?? this.secondsLeft,
      paused: paused ?? this.paused,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      workSeconds: workSeconds ?? this.workSeconds,
      setsDone: setsDone ?? this.setsDone,
      nextIndex: nextIndex ?? this.nextIndex,
      nextSet: nextSet ?? this.nextSet,
      summary: summary ?? this.summary,
    );
  }
}

/// Pure state machine for the guided session. No timers: the UI calls
/// [tick] once per second.
class SessionEngine {
  const SessionEngine._();

  /// Starts a session on the first exercise.
  static SessionState start(List<SessionItem> items) {
    if (items.isEmpty) return const SessionState.empty();
    return _enterWork(
      SessionState(
        items: items,
        workSeconds: List<int>.filled(items.length, 0),
        setsDone: List<int>.filled(items.length, 0),
      ),
      0,
      0,
    );
  }

  /// Advances the clock by one second.
  static SessionState tick(SessionState s) {
    if (s.paused || s.isFinished || s.items.isEmpty) return s;
    var n = s.copyWith(elapsedSeconds: s.elapsedSeconds + 1);

    if (s.phase == SessionPhase.work) {
      final work = [...s.workSeconds];
      work[s.index] += 1;
      n = n.copyWith(workSeconds: work);
      if (s.current.timed) {
        final left = s.secondsLeft - 1;
        n = n.copyWith(secondsLeft: left);
        if (left <= 0) return completeSet(n);
      }
      return n;
    }

    final left = s.secondsLeft - 1;
    n = n.copyWith(restSeconds: s.restSeconds + 1, secondsLeft: left);
    if (left <= 0) return skipRest(n);
    return n;
  }

  /// Marks the current set done and starts rest, or finishes the workout.
  static SessionState completeSet(SessionState s) {
    if (s.phase != SessionPhase.work || s.items.isEmpty) return s;
    final item = s.current;
    final done = [...s.setsDone];
    done[s.index] = math.max(done[s.index], s.setIndex + 1);
    final marked = s.copyWith(setsDone: done);

    int targetIndex;
    int targetSet;
    if (s.setIndex + 1 < item.sets) {
      targetIndex = s.index;
      targetSet = s.setIndex + 1;
    } else if (s.index + 1 < s.items.length) {
      targetIndex = s.index + 1;
      targetSet = 0;
    } else {
      return finish(marked);
    }

    if (item.restSec > 0) {
      return marked.copyWith(
        phase: SessionPhase.rest,
        secondsLeft: item.restSec,
        nextIndex: targetIndex,
        nextSet: targetSet,
        paused: false,
      );
    }
    return _enterWork(marked, targetIndex, targetSet);
  }

  /// Ends the rest period early.
  static SessionState skipRest(SessionState s) {
    if (s.phase != SessionPhase.rest) return s;
    return _enterWork(s, s.nextIndex, s.nextSet);
  }

  /// Adds time to the current rest.
  static SessionState addRestTime(SessionState s, [int seconds = 15]) {
    if (s.phase != SessionPhase.rest) return s;
    return s.copyWith(secondsLeft: s.secondsLeft + seconds);
  }

  /// Jumps to the start of the next exercise (finishes after the last one).
  static SessionState next(SessionState s) {
    if (s.isFinished || s.items.isEmpty) return s;
    final target = s.displayIndex + 1;
    if (target >= s.items.length) return finish(s);
    return _enterWork(s, target, 0);
  }

  /// Jumps to the start of the previous exercise (restarts the first one).
  static SessionState previous(SessionState s) {
    if (s.isFinished || s.items.isEmpty) return s;
    final target = s.displayIndex > 0 ? s.displayIndex - 1 : 0;
    return _enterWork(s, target, 0);
  }

  static SessionState togglePause(SessionState s) =>
      s.isFinished ? s : s.copyWith(paused: !s.paused);

  /// Ends the session now (keeps whatever was completed).
  static SessionState finish(SessionState s) =>
      s.copyWith(phase: SessionPhase.finished, secondsLeft: 0, paused: false);

  /// Duration, calories and completed exercise count.
  static SessionSummary summarize(SessionState s, double weightKg) {
    final segments = [
      for (var i = 0; i < s.items.length; i++)
        (met: s.items[i].exercise.met, seconds: s.workSeconds[i]),
    ];
    var completed = 0;
    for (var i = 0; i < s.items.length; i++) {
      if (s.setsDone[i] >= s.items[i].sets) completed++;
    }
    final minutes = s.elapsedSeconds == 0
        ? 0
        : math.max(1, (s.elapsedSeconds / 60).round());
    return SessionSummary(
      durationSeconds: s.elapsedSeconds,
      durationMin: minutes,
      calories: estimateSessionCalories(
        activeSegments: segments,
        restSeconds: s.restSeconds,
        weightKg: weightKg,
      ),
      exercisesCompleted: completed,
      totalExercises: s.items.length,
    );
  }

  static SessionState _enterWork(SessionState s, int index, int setIndex) {
    final item = s.items[index];
    return s.copyWith(
      index: index,
      setIndex: setIndex,
      phase: SessionPhase.work,
      secondsLeft: item.timed ? (item.prescription.durationSec ?? 0) : 0,
      paused: false,
    );
  }
}
