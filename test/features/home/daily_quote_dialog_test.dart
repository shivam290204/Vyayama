import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/motivation/data/quote.dart';
import 'package:fitbuddy/features/motivation/widgets/daily_quote_dialog.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyQuoteDialog', () {
    const testQuote = Quote(
      id: 'q1',
      text: 'The body achieves what the mind believes.',
      author: 'Napoleon Hill',
    );

    testWidgets('renders quote text, author, and cross button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DailyQuoteDialog(quote: testQuote),
            ),
          ),
        ),
      );

      expect(find.text('"The body achieves what the mind believes."'), findsOneWidget);
      expect(find.text('— Napoleon Hill'), findsOneWidget);
      expect(find.text('DAILY SPARK'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text("Let's Crush Today! 💪"), findsOneWidget);
    });

    testWidgets('cross button closes the dialog when tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => DailyQuoteDialog.show(context, testQuote),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyQuoteDialog), findsOneWidget);

      // Tap the cross button
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.byType(DailyQuoteDialog), findsNothing);
    });

    testWidgets('checkAndShow records date and does not show twice on same day', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayProvider.overrideWithValue(DateTime(2026, 10, 14)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => DailyQuoteDialog.checkAndShow(context, ref),
                  child: const Text('Trigger Popup'),
                ),
              ),
            ),
          ),
        ),
      );

      // First trigger of the day
      await tester.tap(find.text('Trigger Popup'));
      await tester.pumpAndSettle();

      // Dialog should now be showing
      expect(find.byType(DailyQuoteDialog), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DailyQuoteDialog), findsNothing);

      // Verify pref is set
      expect(prefs.getString(DailyQuoteDialog.prefKey), isNotNull);

      // Second trigger on same day
      await tester.tap(find.text('Trigger Popup'));
      await tester.pumpAndSettle();

      // Dialog should NOT appear again
      expect(find.byType(DailyQuoteDialog), findsNothing);
    });
  });
}
