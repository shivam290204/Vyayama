import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/workouts/widgets/browse_plans_tab.dart';

void main() {
  Widget buildSubject() {
    return const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: BrowsePlansTab(),
        ),
      ),
    );
  }

  group('BrowsePlansTab UI/UX Tests', () {
    testWidgets('renders clean header and all 5 bodyweight routines with correct button titles',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Bodyweight Workouts'), findsOneWidget);
      expect(
        find.text('Zero-equipment guided routines • Exercise animations included'),
        findsOneWidget,
      );

      // Verify no long paragraph descriptions are rendered
      expect(
        find.textContaining('Prime your joints, activate key muscle groups'),
        findsNothing,
      );
      expect(
        find.textContaining('Build basic fitness, learn correct exercise techniques'),
        findsNothing,
      );
      expect(
        find.textContaining('Maximize relative strength, power, and athletic control'),
        findsNothing,
      );

      // Verify button labels: natural phrasing without awkward "Start Beginner" / "Start Advanced"
      expect(find.text('Start Warm-up'), findsOneWidget);
      expect(find.text('Start Workout'), findsNWidgets(3)); // Beginner, Intermediate, Advanced
      expect(find.text('Start Beginner'), findsNothing);
      expect(find.text('Start Intermediate'), findsNothing);
      expect(find.text('Start Advanced'), findsNothing);
      expect(find.text('Start Cool-down'), findsOneWidget);

      // Verify difficulty badges are present
      expect(find.text('Warm-up'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('Cool-down'), findsOneWidget);
    });

    testWidgets('tapping preview toggle expands and collapses exercise list', (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Initially exercise preview is collapsed
      expect(find.text('Preview all 14 exercises'), findsNWidgets(2)); // Warm-up (14) & Advanced (14)
      expect(find.text('Hide exercises'), findsNothing);

      // Tap the first preview toggle (Warm-up)
      await tester.tap(find.text('Preview all 14 exercises').first);
      await tester.pumpAndSettle();

      // Now it shows 'Hide exercises'
      expect(find.text('Hide exercises'), findsOneWidget);

      // Tap it again to collapse
      await tester.tap(find.text('Hide exercises'));
      await tester.pumpAndSettle();

      expect(find.text('Hide exercises'), findsNothing);
    });
  });
}
