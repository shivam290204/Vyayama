import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/intelligence/domain/models/fitness_insight.dart';
import 'package:fitbuddy/features/intelligence/presentation/widgets/smart_insights_section.dart';
import 'package:fitbuddy/features/intelligence/providers.dart';

void main() {
  group('SmartInsightsSection Widget Tests', () {
    testWidgets('Renders SizedBox.shrink when intelligence is disabled by feature flag', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(false),
            fitnessInsightsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmartInsightsSection(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Smart Insights'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('Renders SizedBox.shrink when insights list is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(true),
            fitnessInsightsProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmartInsightsSection(),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Smart Insights'), findsNothing);
    });

    testWidgets('Renders header and insight cards when insights are available', (tester) async {
      final mockInsights = [
        FitnessInsight(
          id: 'test_1',
          title: 'Target Hit: 3 Workouts',
          message: 'You have achieved your weekly target of 3 sessions.',
          category: InsightCategory.consistency,
          priority: InsightPriority.high,
          actionLabel: 'View Workouts',
          actionRoute: '/workouts',
          createdAt: DateTime.now(),
        ),
        FitnessInsight(
          id: 'test_2',
          title: '7-Day Streak Milestone! 🔥',
          message: 'Consistency milestone reached.',
          category: InsightCategory.streak,
          priority: InsightPriority.high,
          actionLabel: 'View Badges',
          actionRoute: '/challenges',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(true),
            fitnessInsightsProvider.overrideWith((ref) => Future.value(mockInsights)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SmartInsightsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Smart Insights'), findsOneWidget);
      expect(find.text('Target Hit: 3 Workouts'), findsOneWidget);
      expect(find.text('You have achieved your weekly target of 3 sessions.'), findsOneWidget);
      expect(find.text('7-Day Streak Milestone! 🔥'), findsOneWidget);
      expect(find.text('View Workouts'), findsOneWidget);
      expect(find.text('View Badges'), findsOneWidget);
    });

    testWidgets('Renders Notice badge for Urgent priority recovery insight', (tester) async {
      final mockInsights = [
        FitnessInsight(
          id: 'test_urgent',
          title: 'Active Recovery Recommended',
          message: 'You have worked out 3 days in a row.',
          category: InsightCategory.recovery,
          priority: InsightPriority.urgent,
          actionLabel: 'Recovery Tips',
          actionRoute: '/sleep',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            intelligenceEnabledProvider.overrideWithValue(true),
            fitnessInsightsProvider.overrideWith((ref) => Future.value(mockInsights)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SmartInsightsSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Smart Insights'), findsOneWidget);
      expect(find.text('Notice'), findsOneWidget);
      expect(find.text('Active Recovery Recommended'), findsOneWidget);
    });
  });
}
