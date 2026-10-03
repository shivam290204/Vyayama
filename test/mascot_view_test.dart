import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitbuddy/features/mascot/mascot_view.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildMascot(MascotMood mood, double size) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MascotView(
            mood: mood,
            size: size,
          ),
        ),
      ),
    );
  }

  testWidgets('MascotView renders without overflow at size 80', (WidgetTester tester) async {
    for (final mood in MascotMood.values) {
      await tester.pumpWidget(buildMascot(mood, 80));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MascotView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('MascotView renders without overflow at size 240', (WidgetTester tester) async {
    for (final mood in MascotMood.values) {
      await tester.pumpWidget(buildMascot(mood, 240));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(MascotView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
