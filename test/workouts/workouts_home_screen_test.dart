import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/screens/workouts_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final samplePlan = WorkoutPlan(
    id: 'plan_fat_burn',
    title: 'Fat-Burn Starter',
    goal: 'lose',
    level: 'beginner',
    isSystem: true,
    days: [
      PlanDay(
        id: 'day_1',
        dayNumber: 1,
        name: 'Cardio Steps',
        exercises: [
          const PlanExercise(
            id: 'pe_1',
            exerciseId: 'burpee',
            sets: 3,
            reps: 10,
            restSec: 30,
          ),
        ],
      ),
    ],
  );

  final sampleExercise = const Exercise(
    id: 'burpee',
    name: 'Burpee',
    muscleGroup: 'full_body',
    equipment: 'none',
    instructions: ['Drop and jump'],
    commonMistakes: [],
    contraindications: [],
    met: 8.0,
  );

  testWidgets('WorkoutsHomeScreen renders single Create plan button when custom plans empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          defaultPlanProvider.overrideWith((ref) => Future.value(samplePlan)),
          myPlansProvider.overrideWith(() => _MockEmptyMyPlansNotifier()),
          systemPlansProvider.overrideWith((ref) => Future.value([samplePlan])),
          exerciseLibraryProvider.overrideWith((ref) => Future.value([sampleExercise])),
          selectedConditionTagsProvider.overrideWith((ref) => <String>[]),
        ],
        child: const MaterialApp(
          home: WorkoutsHomeScreen(),
        ),
      ),
    );

    // Pump frames to let async providers settle
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify title and tabs ('Workouts' appears as title and as the tab label)
    expect(find.text('Workouts'), findsNWidgets(2));
    expect(find.text('My Plan'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);

    // Verify FloatingActionButton is NOT present
    expect(find.byType(FloatingActionButton), findsNothing);

    // Verify AppBar create plan action is present
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

    // Verify Recommended plan card is displayed with title and active badge
    expect(find.text('Fat-Burn Starter'), findsOneWidget);
    expect(find.text('ACTIVE PLAN'), findsOneWidget);
    expect(find.text('Start workout'), findsOneWidget);
    expect(find.text('View plan'), findsOneWidget);

    // Verify ONLY ONE 'Create plan' button appears on the screen (in the empty state)
    expect(find.widgetWithText(FilledButton, 'Create plan'), findsOneWidget);

    // Verify Build your own plan message is visible
    expect(find.text('Build your own plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WorkoutsHomeScreen shows New plan button when custom plans exist', (tester) async {
    final customPlan = WorkoutPlan(
      id: 'custom_1',
      title: 'My Custom Split',
      goal: 'gain',
      level: 'intermediate',
      isSystem: false,
      days: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          defaultPlanProvider.overrideWith((ref) => Future.value(samplePlan)),
          myPlansProvider.overrideWith(() => _MockFilledMyPlansNotifier([customPlan])),
          systemPlansProvider.overrideWith((ref) => Future.value([samplePlan])),
          exerciseLibraryProvider.overrideWith((ref) => Future.value([sampleExercise])),
          selectedConditionTagsProvider.overrideWith((ref) => <String>[]),
        ],
        child: const MaterialApp(
          home: WorkoutsHomeScreen(),
        ),
      ),
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // FAB is not present
    expect(find.byType(FloatingActionButton), findsNothing);

    // Custom plan title is shown
    expect(find.text('My Custom Split'), findsOneWidget);

    // Header has 'New plan' button
    expect(find.widgetWithText(FilledButton, 'New plan'), findsOneWidget);

    // Empty state 'Create plan' button is NOT shown because plans is not empty
    expect(find.widgetWithText(FilledButton, 'Create plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _MockEmptyMyPlansNotifier extends MyPlansNotifier {
  @override
  Future<List<WorkoutPlan>> build() async => [];
}

class _MockFilledMyPlansNotifier extends MyPlansNotifier {
  _MockFilledMyPlansNotifier(this._plans);
  final List<WorkoutPlan> _plans;

  @override
  Future<List<WorkoutPlan>> build() async => _plans;
}
