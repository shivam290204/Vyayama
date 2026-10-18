import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:fitbuddy/features/workouts/widgets/workout_pip_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final item = SessionItem(
    exercise: ex('Push Ups', 'chest'),
    prescription: pe('p1', 'Push Ups', sets: 3, reps: 12, rest: 45),
  );

  testWidgets('WorkoutPipView renders workout exercise state and responds to taps', (tester) async {
    final state = SessionEngine.start([item]);
    var pauseToggled = false;
    var doneSetTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutPipView(
          state: state,
          onTogglePause: () => pauseToggled = true,
          onNext: () {},
          onDoneSet: () => doneSetTapped = true,
        ),
      ),
    );

    expect(find.text('Push Ups'), findsOneWidget);
    expect(find.text('Set 1 of 3'), findsOneWidget);
    expect(find.text('WORKOUT'), findsOneWidget);

    // Tap pause button
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(pauseToggled, isTrue);

    // Tap complete set button ('Done')
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(doneSetTapped, isTrue);
  });

  testWidgets('WorkoutPipView renders rest state accurately', (tester) async {
    final restingState = SessionEngine.completeSet(SessionEngine.start([item]));

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutPipView(
          state: restingState,
          onTogglePause: () {},
          onNext: () {},
          onDoneSet: () {},
        ),
      ),
    );

    expect(find.text('REST'), findsOneWidget);
    expect(find.text('Resting'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
