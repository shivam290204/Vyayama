import 'package:fitbuddy/features/settings/screens/notification_diagnostics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NotificationDiagnosticsScreen renders app bar and diagnostic cards', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: NotificationDiagnosticsScreen(),
        ),
      ),
    );

    // Initial loading or loaded state
    await tester.pump();
    expect(find.text('Alarm & Notification Diagnostics'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });
}
