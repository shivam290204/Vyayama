import 'package:fitbuddy/core/router/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Maps Navigation and AppBottomBar Tests', () {
    testWidgets('1. AppBottomBar renders exactly 5 clean navigation tabs', (tester) async {
      int selectedBranch = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomBar(
              selectedBranch: selectedBranch,
              onBranchSelected: (idx) => selectedBranch = idx,
              friendsBadgeCount: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 5 tab labels exist
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Tap Maps tab (branch 2)
      await tester.tap(find.text('Maps'));
      await tester.pumpAndSettle();
      expect(selectedBranch, equals(2));

      // Tap Workouts tab (branch 1)
      await tester.tap(find.text('Workouts'));
      await tester.pumpAndSettle();
      expect(selectedBranch, equals(1));

      // Tap Friends tab (branch 3)
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(selectedBranch, equals(3));

      // Tap Profile tab (branch 4)
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(selectedBranch, equals(4));
    });
  });
}
