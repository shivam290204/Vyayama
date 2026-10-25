import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/services/health_service.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/settings/widgets/connected_health_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HealthService.instance.resetForTesting();
  });

  tearDown(() {
    HealthService.instance.resetForTesting();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      theme: AppTheme.dark(useGoogleFonts: false),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: ConnectedHealthSection(),
        ),
      ),
    );
  }

  testWidgets('displays fallback message when platform is unsupported',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = false;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Connected Health Services'), findsOneWidget);
    expect(
      find.text(
          'Health Connect on Android and Apple Health on iOS are supported.'),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('displays Google Health Connect UI when supported on Android',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Connected Health Services'), findsOneWidget);
    expect(find.text('Google Health Connect'), findsOneWidget);
    expect(find.text('Sync steps and calories from your health apps'),
        findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
    expect(find.text('Sync Now'), findsNothing);
  });

  testWidgets('displays Apple Health UI and active state when sync is enabled',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      HealthService.kHealthSyncEnabledKey: true,
    });
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Apple Health';

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Connected Health Services'), findsOneWidget);
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.text('Connected • Steps and active calories can sync'),
        findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);
    expect(find.text('Sync Now'), findsOneWidget);

    // Tapping disconnect switch
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(HealthService.kHealthSyncEnabledKey), isFalse);
    expect(find.text('Disconnected from Apple Health.'), findsOneWidget);
  });
}
