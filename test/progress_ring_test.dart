import 'package:fitbuddy/features/home/widgets/progress_ring.dart';
import 'package:fitbuddy/features/home/widgets/progress_ring_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProgressRing.progressFraction', () {
    test('returns 0 when goal is 0', () {
      expect(ProgressRing.progressFraction(5000, 0), 0.0);
    });

    test('returns 0 when goal is negative', () {
      expect(ProgressRing.progressFraction(5000, -1), 0.0);
    });

    test('returns 0 when value is 0', () {
      expect(ProgressRing.progressFraction(0, 8000), 0.0);
    });

    test('returns correct fraction at 50%', () {
      expect(ProgressRing.progressFraction(4000, 8000), 0.5);
    });

    test('clamps to 1.0 when value exceeds goal', () {
      expect(ProgressRing.progressFraction(12000, 8000), 1.0);
    });

    test('clamps to 1.0 at exactly 100%', () {
      expect(ProgressRing.progressFraction(8000, 8000), 1.0);
    });

    test('handles small fractions', () {
      expect(
        ProgressRing.progressFraction(800, 8000),
        closeTo(0.1, 0.001),
      );
    });
  });

  group('ProgressRingPainter', () {
    test('shouldRepaint returns true when progress changes', () {
      final a = ProgressRingPainter(
        progress: 0.5,
        ringColor: Colors.blue,
        trackColor: Colors.grey,
        strokeWidth: 6.0,
      );
      final b = ProgressRingPainter(
        progress: 0.7,
        ringColor: Colors.blue,
        trackColor: Colors.grey,
        strokeWidth: 6.0,
      );
      expect(a.shouldRepaint(b), isTrue);
    });

    test('shouldRepaint returns false when values are equal', () {
      final a = ProgressRingPainter(
        progress: 0.5,
        ringColor: Colors.blue,
        trackColor: Colors.grey,
        strokeWidth: 6.0,
      );
      final b = ProgressRingPainter(
        progress: 0.5,
        ringColor: Colors.blue,
        trackColor: Colors.grey,
        strokeWidth: 6.0,
      );
      expect(a.shouldRepaint(b), isFalse);
    });
  });

  group('ProgressRing widget', () {
    Widget buildRing({
      int value = 5000,
      int goal = 8000,
      bool reduceMotion = false,
    }) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: ProgressRing(
                value: value,
                goal: goal,
                ringColor: Colors.blue,
                trackColor: Colors.grey.shade300,
                icon: Icons.directions_walk,
                label: 'steps',
                semanticGoalLabel: 'Steps',
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(buildRing(value: 5000, goal: 8000));
      await tester.pumpAndSettle();
      expect(find.text('steps'), findsOneWidget);
      expect(find.text('5,000'), findsOneWidget);
    });

    testWidgets('renders with 0 goal without errors', (tester) async {
      await tester.pumpWidget(buildRing(value: 100, goal: 0));
      await tester.pumpAndSettle();
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('renders with value exceeding goal', (tester) async {
      await tester.pumpWidget(buildRing(value: 12000, goal: 8000));
      await tester.pumpAndSettle();
      expect(find.text('12,000'), findsOneWidget);
      // Should show completion check badge.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows completion check badge at 100%', (tester) async {
      await tester.pumpWidget(buildRing(value: 8000, goal: 8000));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('no check badge below 100%', (tester) async {
      await tester.pumpWidget(buildRing(value: 4000, goal: 8000));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('semantics label is correct', (tester) async {
      await tester.pumpWidget(buildRing(value: 5566, goal: 8000));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(find.byType(ProgressRing));
      expect(semantics.label, contains('Steps'));
      expect(semantics.label, contains('5,566'));
      expect(semantics.label, contains('8,000'));
    });

    testWidgets('reduce-motion skips animation', (tester) async {
      await tester.pumpWidget(
        buildRing(value: 4000, goal: 8000, reduceMotion: true),
      );
      // One frame should be enough since duration is zero.
      await tester.pump();
      expect(find.text('4,000'), findsOneWidget);
    });
  });
}
