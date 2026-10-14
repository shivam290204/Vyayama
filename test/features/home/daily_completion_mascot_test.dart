import 'package:fitbuddy/features/dashboard/daily_targets.dart';
import 'package:fitbuddy/features/dashboard/data/daily_stats.dart';
import 'package:fitbuddy/features/dashboard/providers.dart';
import 'package:fitbuddy/features/home/providers/daily_completion_provider.dart';
import 'package:fitbuddy/features/home/widgets/mascot_section.dart';
import 'package:fitbuddy/features/home/widgets/speech_bubble.dart';
import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StaticTierNotifier extends DailyCompletionTierOverrideNotifier {
  _StaticTierNotifier(this._initialTier);
  final DailyCompletionTier _initialTier;

  @override
  DailyCompletionTier? build() => _initialTier;
}

void main() {
  group('DailyCompletionTier and Progress', () {
    test('Correct assets correspond to each completion tier', () {
      const pNothing = DailyCompletionProgress(
        completedCount: 0,
        totalCount: 6,
        tier: DailyCompletionTier.nothingDone,
        stepsDone: false,
        caloriesDone: false,
        activeMinutesDone: false,
        workoutDone: false,
        waterDone: false,
        challengeDone: false,
      );
      expect(pNothing.assetPath, 'assets/images/mascot/Sad_Drooped_Head.png');

      const pPartial = DailyCompletionProgress(
        completedCount: 4,
        totalCount: 6,
        tier: DailyCompletionTier.fourToFiveDone,
        stepsDone: true,
        caloriesDone: true,
        activeMinutesDone: true,
        workoutDone: true,
        waterDone: false,
        challengeDone: false,
      );
      expect(pPartial.assetPath, 'assets/images/mascot/flex_proud.png');

      const pAll = DailyCompletionProgress(
        completedCount: 6,
        totalCount: 6,
        tier: DailyCompletionTier.everythingDone,
        stepsDone: true,
        caloriesDone: true,
        activeMinutesDone: true,
        workoutDone: true,
        waterDone: true,
        challengeDone: true,
      );
      expect(pAll.assetPath, 'assets/images/mascot/Fire_Determined.png');
    });

    test('Override notifier cycles through tiers correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(dailyCompletionTierOverrideProvider.notifier);

      expect(container.read(dailyCompletionTierOverrideProvider), isNull);

      notifier.cycleNext();
      expect(container.read(dailyCompletionTierOverrideProvider),
          DailyCompletionTier.fourToFiveDone);

      notifier.cycleNext();
      expect(container.read(dailyCompletionTierOverrideProvider),
          DailyCompletionTier.everythingDone);

      notifier.cycleNext();
      expect(container.read(dailyCompletionTierOverrideProvider),
          DailyCompletionTier.nothingDone);

      notifier.cycleNext();
      expect(container.read(dailyCompletionTierOverrideProvider), isNull);
    });

    test('Calculates fourToFiveDone when 4 or 5 schedule tasks are completed', () {
      final entries = List.generate(
        6,
        (i) => TimeBlockEntry(
          block: TimeBlock(
            id: 'blk-$i',
            userId: 'user',
            type: BlockType.meal,
            title: 'Task $i',
            startMinutes: 8 * 60 + i * 60,
          ),
          status: i < 4 ? BlockStatus.done : BlockStatus.upcoming,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          todayScheduleProvider.overrideWithValue(AsyncData(entries)),
        ],
      );
      addTearDown(container.dispose);

      final progress = container.read(dailyCompletionProgressProvider);
      expect(progress.completedCount, 4);
      expect(progress.tier, DailyCompletionTier.fourToFiveDone);
      expect(progress.assetPath, 'assets/images/mascot/flex_proud.png');
    });

    test('Calculates everythingDone when 6 schedule tasks are completed', () {
      final entries = List.generate(
        6,
        (i) => TimeBlockEntry(
          block: TimeBlock(
            id: 'blk-$i',
            userId: 'user',
            type: BlockType.meal,
            title: 'Task $i',
            startMinutes: 8 * 60 + i * 60,
          ),
          status: BlockStatus.done,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          todayScheduleProvider.overrideWithValue(AsyncData(entries)),
        ],
      );
      addTearDown(container.dispose);

      final progress = container.read(dailyCompletionProgressProvider);
      expect(progress.completedCount, 6);
      expect(progress.tier, DailyCompletionTier.everythingDone);
      expect(progress.assetPath, 'assets/images/mascot/Fire_Determined.png');
    });

    test('Calculates everythingDone when daily walking steps goal is reached', () {
      final container = ProviderContainer(
        overrides: [
          todayStatsProvider.overrideWithValue(
            AsyncData(
              DailyStats(
                id: 'stats-1',
                userId: 'user',
                date: DateTime(2026, 10, 14),
                steps: 10000,
                calories: 500,
                activeMinutes: 45,
              ),
            ),
          ),
          dailyTargetsProvider.overrideWithValue(
            const DailyTargets(steps: 8000, activeCalories: 500, activeMinutes: 30),
          ),
        ],
      );
      addTearDown(container.dispose);

      final progress = container.read(dailyCompletionProgressProvider);
      expect(progress.stepsDone, isTrue);
      expect(progress.tier, DailyCompletionTier.everythingDone);
      expect(progress.assetPath, 'assets/images/mascot/Fire_Determined.png');
    });
  });

  group('MascotSection Widget', () {
    testWidgets('Renders Sad_Drooped_Head.png when nothing done',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyCompletionTierOverrideProvider.overrideWith(
              () => _StaticTierNotifier(DailyCompletionTier.nothingDone),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MascotSection(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(SpeechBubble), findsOneWidget);
      expect(find.byType(MascotSection), findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName,
          'assets/images/mascot/Sad_Drooped_Head.png');
    });

    testWidgets('Renders flex_proud.png when 4 to 5 things done',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyCompletionTierOverrideProvider.overrideWith(
              () => _StaticTierNotifier(DailyCompletionTier.fourToFiveDone),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MascotSection(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName,
          'assets/images/mascot/flex_proud.png');
    });

    testWidgets('Renders Fire_Determined.png when everything done',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyCompletionTierOverrideProvider.overrideWith(
              () => _StaticTierNotifier(DailyCompletionTier.everythingDone),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MascotSection(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect((image.image as AssetImage).assetName,
          'assets/images/mascot/Fire_Determined.png');
    });
  });
}
