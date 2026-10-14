import 'package:fitbuddy/features/sleep/presentation/sleep_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SleepScreen renders without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SleepScreen(),
        ),
      ),
    );
    await tester.pump();
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Sleep & alarm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
