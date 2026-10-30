import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/workouts/screens/exercise_detail_screen.dart';
import 'package:fitbuddy/features/workouts/screens/plan_builder_screen.dart';
import 'package:fitbuddy/features/workouts/screens/plan_detail_screen.dart';
import 'package:fitbuddy/features/workouts/screens/workout_session_screen.dart';
import 'package:fitbuddy/features/workouts/screens/workouts_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleExercise = const Exercise(
    id: 'push_up',
    name: 'Push Up',
    muscleGroup: 'chest',
    equipment: 'none',
    instructions: ['Place hands shoulder-width apart', 'Lower chest to floor', 'Push back up'],
    commonMistakes: ['Flaring elbows out too wide', 'Sagging lower back'],
    contraindications: ['wrist', 'shoulder'],
    met: 4.0,
  );

  final sampleExercise2 = const Exercise(
    id: 'bodyweight_squat',
    name: 'Bodyweight Squat',
    muscleGroup: 'quads',
    equipment: 'none',
    instructions: ['Stand with feet shoulder-width', 'Lower hips until thighs parallel', 'Push through heels'],
    commonMistakes: ['Knees caving in', 'Rounding back'],
    contraindications: ['knee'],
    met: 5.0,
  );

  final samplePlan = WorkoutPlan(
    id: 'test_plan_1',
    title: 'Beginner Full Body',
    goal: 'maintain',
    level: 'beginner',
    isSystem: true,
    days: [
      PlanDay(
        id: 'day_1',
        dayNumber: 1,
        name: 'Full Body A',
        exercises: [
          const PlanExercise(
            id: 'pe_1',
            exerciseId: 'push_up',
            sets: 2,
            reps: 10,
            restSec: 30,
          ),
          const PlanExercise(
            id: 'pe_2',
            exerciseId: 'bodyweight_squat',
            sets: 2,
            reps: 15,
            restSec: 30,
          ),
        ],
      ),
    ],
  );

  Widget createTestWidget(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        defaultPlanProvider.overrideWith((ref) => Future.value(samplePlan)),
        systemPlansProvider.overrideWith((ref) => Future.value([samplePlan])),
        exerciseLibraryProvider.overrideWith((ref) => Future.value([sampleExercise, sampleExercise2])),
        exerciseByIdProvider('push_up').overrideWith((ref) => Future.value(sampleExercise)),
        exerciseByIdProvider('bodyweight_squat').overrideWith((ref) => Future.value(sampleExercise2)),
        planByIdProvider('test_plan_1').overrideWith((ref) => Future.value(samplePlan)),
        adaptedPlanProvider('test_plan_1').overrideWith(
          (ref) => Future.value(AdaptationResult(plan: samplePlan, notes: const [])),
        ),
        selectedConditionTagsProvider.overrideWith((ref) => <String>['knee']),
        sessionPlanProvider('day_1').overrideWith((ref) => Future.value(
              SessionPlan(
                plan: samplePlan,
                day: samplePlan.days.first,
                items: [
                  SessionItem(
                    exercise: sampleExercise,
                    prescription: samplePlan.days.first.exercises[0],
                  ),
                  SessionItem(
                    exercise: sampleExercise2,
                    prescription: samplePlan.days.first.exercises[1],
                  ),
                ],
                notes: const [],
              ),
            )),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: child,
      ),
    );
  }

  group('Workouts Feature Comprehensive QA Walkthrough', () {
    testWidgets('1. Walks WorkoutsHomeScreen tabs: My Plan, Browse Plans, Exercises', (tester) async {
      await tester.pumpWidget(createTestWidget(const WorkoutsHomeScreen()));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify My Plan tab is initial
      expect(find.text('My Plan'), findsOneWidget);
      expect(find.text('Recommended for you'), findsOneWidget);
      expect(find.text('Beginner Full Body'), findsOneWidget);

      // Tap on Browse Plans tab (Workouts tab header)
      final browseTab = find.text('Workouts').last;
      await tester.tap(browseTab);
      await tester.pumpAndSettle();

      // Tap on Exercises tab
      final exercisesTab = find.text('Exercises');
      await tester.tap(exercisesTab);
      await tester.pumpAndSettle();

      // Verify Exercises tab UI elements
      expect(find.text('Search exercises...'), findsOneWidget);
      expect(find.text('Safe for my conditions'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify search query input and clear button
      await tester.enterText(find.byType(TextField), 'Push');
      await tester.pumpAndSettle();
      expect(find.text('Push Up'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Toggle Safe for my conditions switch
      final safeSwitch = find.byType(Switch);
      expect(safeSwitch, findsOneWidget);
      await tester.tap(safeSwitch);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Walks PlanDetailScreen: days, exercises, and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const PlanDetailScreen(planId: 'test_plan_1')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify plan details loaded
      expect(find.text('Beginner Full Body'), findsOneWidget);
      expect(find.text('Monday · Full Body A'), findsOneWidget);

      // Check Start Workout button
      expect(find.textContaining('Start workout'), findsWidgets);

      // Check medical disclaimer notice
      expect(find.textContaining('General wellness information'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Walks ExerciseDetailScreen: instructions, form tips, contraindications', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const ExerciseDetailScreen(exerciseId: 'push_up')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify exercise information rendered
      expect(find.text('Push Up'), findsWidgets);
      expect(find.text('How to do it'), findsOneWidget);
      expect(find.text('Place hands shoulder-width apart'), findsOneWidget);

      // Verify common mistakes section
      expect(find.text('Common mistakes'), findsOneWidget);
      expect(find.text('Flaring elbows out too wide'), findsOneWidget);

      // Verify contraindication tags section
      expect(find.textContaining('Take extra care'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Walks WorkoutSessionScreen: set completion, rest timer, controls, summary', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const WorkoutSessionScreen(dayId: 'day_1')));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify session started
      expect(find.text('Push Up'), findsOneWidget);
      expect(find.text('Set 1 of 2'), findsOneWidget);

      // Tap Done set button
      final doneSetBtn = find.text('Done set');
      expect(doneSetBtn, findsOneWidget);
      await tester.tap(doneSetBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify rest countdown view is active
      expect(find.text('Rest'), findsOneWidget);
      expect(find.text('15 s'), findsOneWidget);
      expect(find.text('Skip rest'), findsOneWidget);

      // Tap 15 s to extend rest
      await tester.tap(find.text('15 s'));
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Skip rest to advance immediately
      await tester.tap(find.text('Skip rest'));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify Set 2 of 2 is active
      expect(find.text('Set 2 of 2'), findsOneWidget);

      // Complete Set 2 to move to exercise 2
      await tester.tap(find.text('Done set'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Skip rest'));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify next exercise (Bodyweight Squat) is active
      expect(find.text('Bodyweight Squat'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Walks PlanBuilderScreen: day card, add exercise, custom split', (tester) async {
      await tester.pumpWidget(createTestWidget(const PlanBuilderScreen()));
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify builder UI
      expect(find.text('New plan'), findsOneWidget);
      expect(find.text('Plan name'), findsOneWidget);
      expect(find.text('Goal'), findsOneWidget);
      expect(find.text('Level'), findsOneWidget);
      expect(find.text('Workout days'), findsOneWidget);

      // Verify save button exists
      expect(find.text('Save'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
