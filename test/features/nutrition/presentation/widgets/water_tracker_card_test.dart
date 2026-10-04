import 'package:fitbuddy/features/nutrition/data/mock_nutrition_repository.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/water_tracker_card.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(int initialGlasses, {int target = 11, bool reduceMotion = false}) {
    final repo = MockNutritionRepository();
    // Use an exact mock for the day so it starts synchronously or nearly synchronously
    repo.setWaterGlasses(DateTime.now(), initialGlasses);

    return ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(repo),
        waterTargetGlassesProvider.overrideWithValue(target),
      ],
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const MaterialApp(
          home: Scaffold(
            body: WaterTrackerCard(),
          ),
        ),
      ),
    );
  }

  testWidgets('initial state, litre maths and semantics', (tester) async {
    await tester.pumpWidget(buildApp(5));
    await tester.pumpAndSettle();

    // Text assertions
    expect(find.text('5'), findsOneWidget);
    expect(find.text(' / 11'), findsOneWidget);
    // 5 * 250 = 1250 ml = 1.25 L
    // 11 * 250 = 2750 ml = 2.75 L
    expect(find.text('1.25 L of 2.75 L'), findsOneWidget);

    // Semantics
    expect(
      find.bySemanticsLabel('5 of 11 glasses, 1.25 litres'),
      findsOneWidget,
    );
  });

  testWidgets('+ fills exactly one cup', (tester) async {
    await tester.pumpWidget(buildApp(0));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();
    
    // UI animates the text up, so wait until animation finishes to see 1
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('- empties exactly one cup', (tester) async {
    await tester.pumpWidget(buildApp(5));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await tester.pump();
    
    // Wait for the text to animate down
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('cap at goal and zero minimum', (tester) async {
    await tester.pumpWidget(buildApp(11));
    await tester.pumpAndSettle();

    // Check add is disabled
    final addBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));
    expect(addBtn.onPressed, isNull);
    
    // Check goal text
    expect(find.text('Goal reached! '), findsOneWidget);

    await tester.pumpWidget(buildApp(0));
    await tester.pumpAndSettle();

    // Check remove is disabled
    final remBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));
    expect(remBtn.onPressed, isNull);
  });

  testWidgets('reduce-motion skips animations', (tester) async {
    await tester.pumpWidget(buildApp(5, reduceMotion: true));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();
    
    expect(find.text('6'), findsOneWidget);
    // pumpAndSettle will complete instantly if no animations are running
    await tester.pumpAndSettle();
  });
}
