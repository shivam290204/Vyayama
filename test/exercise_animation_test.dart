import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:fitbuddy/features/workouts/widgets/exercise_animation.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  Widget buildAppReduceMotion(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('Semantic label is present', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        const ExerciseAnimation(asset: null, label: 'Push-Up'),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Push-Up demonstration',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Renders Fallback if asset is missing or empty', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        const ExerciseAnimation(asset: '', label: 'Push-Up'),
      ),
    );

    expect(find.text('Demo coming soon'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });

  testWidgets('Renders Lottie for .json extension', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        const ExerciseAnimation(asset: 'test.json', label: 'Push-Up'),
      ),
    );

    expect(find.byType(Lottie), findsOneWidget);
  });

  testWidgets('Renders Fallback for old exercises without poses (e.g. unknown .png)', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        const ExerciseAnimation(asset: 'old.png', poses: [], label: 'Push-Up'),
      ),
    );

    expect(find.text('Demo coming soon'), findsOneWidget);
  });

  testWidgets('Renders SvgPoseRenderer if poses are valid SVGs', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        const ExerciseAnimation(
          asset: 'pushup', 
          poses: ['start.svg', 'end.svg'], 
          label: 'Push-Up'
        ),
      ),
    );

    // Initial state: first pose is shown
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Finish'), findsNothing);

    // Wait for timer
    await tester.pump(const Duration(milliseconds: 1500));

    expect(find.text('Start'), findsNothing);
    expect(find.text('Finish'), findsOneWidget);
  });

  testWidgets('SvgPoseRenderer renders side-by-side with reduce motion', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildAppReduceMotion(
        const ExerciseAnimation(
          asset: 'pushup', 
          poses: ['start.svg', 'end.svg'], 
          label: 'Push-Up'
        ),
      ),
    );

    // Side-by-side should have both Start and Finish visible at the same time
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
  });
}
