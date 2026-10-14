import 'package:fitbuddy/features/home/providers/daily_completion_provider.dart';
import 'package:fitbuddy/features/home/widgets/mascot_section.dart';
import 'package:fitbuddy/features/home/widgets/speech_bubble.dart';
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
