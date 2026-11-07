import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/health_profile/data/profile_snapshot.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/calorie_target_card.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/macro_card.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/water_tracker_card.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWaterNotifier extends WaterNotifier {
  @override
  Future<int> build() async => 4;
}

void main() {
  const mockProfile = ProfileSnapshot(
    id: 'user_1',
    name: 'Test User',
    age: 26,
    gender: 'male',
    weightKg: 72.0,
    heightCm: 178.0,
    goal: 'maintain',
  );

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        profileSnapshotProvider.overrideWithValue(
          const AsyncValue.data(mockProfile),
        ),
        waterProvider.overrideWith(_FakeWaterNotifier.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('CalorieTargetCard Declutter', () {
    testWidgets('renders goals, 4 activity levels, and BMR/TDEE cleanly without broken wrap', (tester) async {
      await tester.pumpWidget(createTestWidget(const CalorieTargetCard()));
      await tester.pumpAndSettle();

      expect(find.text('Daily Calorie Target'), findsOneWidget);
      expect(find.text('Lose'), findsOneWidget);
      expect(find.text('Maintain'), findsOneWidget);
      expect(find.text('Gain'), findsOneWidget);

      expect(find.text('Sedentary'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      expect(find.text('Recommended Daily Range'), findsOneWidget);
      expect(find.text('Resting Energy (BMR)'), findsOneWidget);
      expect(find.text('With Activity (TDEE)'), findsOneWidget);

      // Verify duplicate medical disclaimer was removed
      expect(find.textContaining('This is a general estimate, not medical advice'), findsNothing);
    });
  });

  group('MacroCard Declutter', () {
    testWidgets('renders proportional macro split without fake summary or fake 3-dots', (tester) async {
      await tester.pumpWidget(createTestWidget(const MacroCard()));
      await tester.pumpAndSettle();

      expect(find.text('Macronutrient Split'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fats'), findsOneWidget);

      // Verify fake elements are absent
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.text('SUMMARY 100%'), findsNothing);
      expect(find.text('SUMMARY'), findsNothing);
      expect(find.text('100%'), findsNothing);
    });
  });

  group('WaterTrackerCard Declutter', () {
    testWidgets('renders water tracker cleanly without mascot image in header', (tester) async {
      await tester.pumpWidget(createTestWidget(const WaterTrackerCard()));
      await tester.pumpAndSettle();

      expect(find.text('Water Tracker'), findsOneWidget);
      expect(find.text('glasses today'), findsOneWidget);
      expect(find.textContaining('Stay hydrated!'), findsOneWidget);

      // Mascot image in header should be gone
      expect(find.byType(Image), findsNothing);
    });
  });
}
