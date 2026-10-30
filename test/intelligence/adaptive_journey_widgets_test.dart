import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/intelligence/domain/interfaces/adaptive_journey_interface.dart';
import 'package:fitbuddy/features/intelligence/domain/models/journey_recommendation.dart';
import 'package:fitbuddy/features/intelligence/domain/models/user_fitness_preferences.dart';
import 'package:fitbuddy/features/intelligence/presentation/screens/fitness_preferences_screen.dart';
import 'package:fitbuddy/features/intelligence/presentation/widgets/adaptive_journey_card.dart';
import 'package:fitbuddy/features/intelligence/presentation/widgets/post_workout_feedback_card.dart';
import 'package:fitbuddy/features/intelligence/presentation/widgets/weekly_review_sheet.dart';
import 'package:fitbuddy/features/intelligence/providers.dart';

void main() {
  group('AdaptiveJourneyCard Widget Tests', () {
    const dummyJourney = JourneyRecommendation(
      goalTitle: 'Muscle & Strength',
      journeyStatus: JourneyStatus.progressingSteadily,
      weeklyTargetSessions: 3,
      completedSessionsThisWeek: 2,
      remainingSessionsThisWeek: 1,
      recommendedNextWorkoutTitle: 'Full Body A - Strength Focus',
      suggestedDurationMinutes: 30,
      suggestedDifficulty: 'Progressive Overload',
      weeklyProgressSummary: 'Completed 2 of 3 workouts this week.',
      recommendationReason:
          'Your last few workouts were consistent. Your next session can include a small progression.',
      recommendedPlanDayId: 'day_a',
      isRecovery: false,
    );

    testWidgets('Renders journey details when enabled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(true),
            adaptiveJourneyProvider.overrideWith((ref) => Future.value(dummyJourney)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdaptiveJourneyCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Adaptive Fitness Journey'), findsOneWidget);
      expect(find.text('Muscle & Strength'), findsOneWidget);
      expect(find.text('Progressing Steadily'), findsOneWidget);
      expect(find.text('Full Body A - Strength Focus'), findsOneWidget);
      expect(find.text('Start Workout'), findsOneWidget);
      expect(find.text('Review'), findsOneWidget);
    });

    testWidgets('Renders SizedBox.shrink when feature flag is disabled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(false),
            adaptiveJourneyProvider.overrideWith((ref) => Future.value(dummyJourney)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AdaptiveJourneyCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Adaptive Fitness Journey'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });
  });

  group('PostWorkoutFeedbackCard Widget Tests', () {
    testWidgets('Renders 3 feedback buttons and updates on tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostWorkoutFeedbackCard(planDayId: 'day_test'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('How did this workout feel?'), findsOneWidget);
      expect(find.text('Too Easy'), findsOneWidget);
      expect(find.text('Just Right'), findsOneWidget);
      expect(find.text('Too Hard'), findsOneWidget);

      // Tap 'Just Right'
      await tester.tap(find.text('Just Right'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Feedback noted (Just Right)!'), findsOneWidget);
    });

    testWidgets('Renders SizedBox.shrink when intelligence is disabled', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PostWorkoutFeedbackCard(planDayId: 'day_test'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('How did this workout feel?'), findsNothing);
    });
  });

  group('FitnessPreferencesScreen Widget Tests', () {
    testWidgets('Renders all equipment, duration, and time choices', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final defaultPrefs = UserFitnessPreferences.defaults(userId: 'u_tester');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userFitnessPreferencesProvider.overrideWith(
              () => _FakePreferencesNotifier(defaultPrefs),
            ),
          ],
          child: const MaterialApp(
            home: FitnessPreferencesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fitness Preferences'), findsOneWidget);
      expect(find.text('Available Equipment'), findsOneWidget);
      expect(find.text('Bodyweight / No equipment'), findsOneWidget);
      expect(find.text('Dumbbells'), findsOneWidget);
      expect(find.text('Resistance bands'), findsOneWidget);
      expect(find.text('Barbell'), findsOneWidget);
      expect(find.text('Full gym'), findsOneWidget);

      expect(find.text('15 minutes'), findsOneWidget);
      expect(find.text('30 minutes'), findsOneWidget);
      expect(find.text('45 minutes'), findsOneWidget);

      expect(find.text('Save Preferences'), findsOneWidget);
    });
  });

  group('WeeklyReviewSheet Widget Tests', () {
    testWidgets('Renders weekly review metrics and celebrations', (tester) async {
      final review = WeeklyFitnessReview(
        weekStartDate: DateTime(2026, 10, 22),
        weekEndDate: DateTime(2026, 10, 29),
        completedSessions: 3,
        scheduledSessions: 3,
        totalActiveMinutes: 90,
        totalSteps: 45000,
        consistencyScore: 100,
        adherenceSummary: 'Completed 3 of 3 scheduled sessions (100% consistency).',
        recommendedNextFocus: 'Progressive Overload — aim for +1 rep.',
        celebrations: const ['Hit your weekly target of 3 workouts!'],
        areasForImprovement: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => WeeklyReviewSheet.show(context, review),
                child: const Text('Open Review'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Review'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Fitness Review'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Consistency Score'), findsOneWidget);
      expect(find.text('90m'), findsOneWidget);
      expect(find.text('45000'), findsOneWidget);
      expect(find.text('Hit your weekly target of 3 workouts!'), findsOneWidget);
      expect(find.text('Progressive Overload — aim for +1 rep.'), findsOneWidget);
    });
  });
}

class _FakePreferencesNotifier extends UserFitnessPreferencesNotifier {
  _FakePreferencesNotifier(this._initial);
  final UserFitnessPreferences _initial;

  @override
  Future<UserFitnessPreferences> build() async => _initial;

  @override
  Future<void> save(UserFitnessPreferences preferences) async {
    state = AsyncData(preferences);
  }
}

