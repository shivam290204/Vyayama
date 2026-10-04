import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('MascotView draws every mood in $brightness', (tester) async {
      final handle = tester.ensureSemantics();
      for (final mood in MascotMood.values) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                colorSchemeSeed: Colors.teal,
                brightness: brightness,
                useMaterial3: true,
              ),
              home: Scaffold(
                body: Center(child: MascotView(mood: mood, size: 160)),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          find.bySemanticsLabel(RegExp('feeling ${mood.label}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      handle.dispose();
    });
  }

  testWidgets('MascotView fits a small box without overflow', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 100,
              child: MascotView(mood: MascotMood.celebrating, size: 96),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}
