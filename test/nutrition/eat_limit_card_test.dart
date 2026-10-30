import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/eat_limit_card.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleTips = [
    const DietTip(
      id: 't01',
      category: DietTip.eatMore,
      title: 'Colourful vegetables',
      body: 'Aim to fill about half your plate with vegetables.',
    ),
    const DietTip(
      id: 't02',
      category: DietTip.eatMore,
      title: 'Whole grains',
      body: 'Brown rice, oats, ragi and millets keep you fuller.',
    ),
    const DietTip(
      id: 't11',
      category: DietTip.limit,
      title: 'Sugary drinks',
      body: 'Cold drinks and packaged juices add calories quickly.',
    ),
  ];

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        dietTipsProvider.overrideWith((ref) => sampleTips),
      ],
      child: MaterialApp(
        theme: AppTheme.light(useGoogleFonts: false),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: EatLimitCard(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders Food Guide title and tabs', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Food Guide'), findsOneWidget);
    expect(find.text('Eat more of'), findsOneWidget);
    expect(find.text('Limit'), findsOneWidget);

    // Initial tab shows Eat more of items
    expect(find.text('Colourful vegetables'), findsOneWidget);
    expect(find.text('Whole grains'), findsOneWidget);
  });

  testWidgets('switches to Limit tab when tapped', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap Limit tab
    await tester.tap(find.text('Limit'));
    await tester.pumpAndSettle();

    expect(find.text('Sugary drinks'), findsOneWidget);
    expect(find.textContaining('Cold drinks and packaged juices'), findsOneWidget);
  });
}
