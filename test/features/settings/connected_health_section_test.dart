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

  Widget buildTestWidget({ThemeData? theme}) {
    return MaterialApp(
      theme: theme ?? AppTheme.dark(useGoogleFonts: false),
      home: const Scaffold(
        body: SingleChildScrollView(
          child: ConnectedHealthSection(),
        ),
      ),
    );
  }

  testWidgets('displays fallback message when platform is unsupported', (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = false;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Connected Health Services'), findsOneWidget);
    expect(
      find.text('Health Connect / Apple Health sync is supported on Android and iOS devices.'),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('displays Google Health Connect UI when supported on Android', (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';
    HealthService.instance.hasPermissionsOverride = false;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Connected Health Services'), findsOneWidget);
    expect(find.text('Google Health Connect'), findsOneWidget);
    expect(find.text('Sync steps from smartwatches & health apps'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
    expect(find.text('Sync Now'), findsNothing);
  });

  testWidgets('displays Apple Health UI and active state when sync is enabled', (tester) async {
    SharedPreferences.setMockInitialValues({
      HealthService.kHealthSyncEnabledKey: true,
    });
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Apple Health';
    HealthService.instance.hasPermissionsOverride = true;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Connected Health Services'), findsOneWidget);
    expect(find.text('Apple Health'), findsOneWidget);
    expect(find.text('Active • Synced with Wear OS, Apple Watch & health apps'), findsOneWidget);
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

  testWidgets('displays error and settings action when Health Connect permission fails', (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';
    HealthService.instance.isHealthConnectAvailableOverride = true;
    HealthService.instance.hasPermissionsOverride = false;
    HealthService.instance.requestPermissionsOverride = false;

    await tester.pumpWidget(buildTestWidget(
      theme: ThemeData(platform: TargetPlatform.android),
    ));
    await tester.pumpAndSettle();

    // Tap switch to connect
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Could not connect to Google Health Connect. Please grant permissions in system settings.'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
    expect(find.text('Permission required • Grant access in system settings'), findsOneWidget);
  });

  testWidgets('connects and enables sync when Health Connect permission succeeds', (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';
    HealthService.instance.isHealthConnectAvailableOverride = true;
    HealthService.instance.requestPermissionsOverride = true;
    HealthService.instance.hasPermissionsOverride = true;
    HealthService.instance.stepsTodayOverride = 5000;

    await tester.pumpWidget(buildTestWidget(
      theme: ThemeData(platform: TargetPlatform.android),
    ));
    await tester.pumpAndSettle();

    // Tap switch to connect
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Connected to Google Health Connect! Steps and calories are now synchronized.'), findsOneWidget);
    expect(find.text('Sync Now'), findsOneWidget);

    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(HealthService.kHealthSyncEnabledKey), isTrue);
  });

  testWidgets('displays install prompt when Health Connect is not available on Android', (tester) async {
    SharedPreferences.setMockInitialValues({});
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';
    HealthService.instance.isHealthConnectAvailableOverride = false;
    HealthService.instance.hasPermissionsOverride = false;

    await tester.pumpWidget(buildTestWidget(
      theme: ThemeData(platform: TargetPlatform.android),
    ));
    await tester.pumpAndSettle();

    // Tap switch to connect
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Google Health Connect is not installed or requires an update.'), findsOneWidget);
    expect(find.text('Install'), findsOneWidget);
  });

  testWidgets('shows permission-required state when sync was enabled but permissions subsequently revoked', (tester) async {
    SharedPreferences.setMockInitialValues({
      HealthService.kHealthSyncEnabledKey: true,
    });
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';
    HealthService.instance.hasPermissionsOverride = false; // Permissions revoked in system settings

    await tester.pumpWidget(buildTestWidget(
      theme: ThemeData(platform: TargetPlatform.android),
    ));
    await tester.pumpAndSettle();

    // Must show permission-required state, not active state
    expect(find.text('Permission required • Grant access in system settings'), findsOneWidget);
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isFalse);
    expect(find.text('Sync Now'), findsNothing);
  });

  testWidgets('revalidates permissions when application resumes from system settings', (tester) async {
    SharedPreferences.setMockInitialValues({
      HealthService.kHealthSyncEnabledKey: true,
    });
    HealthService.instance.isSupportedOverride = true;
    HealthService.instance.serviceNameOverride = 'Google Health Connect';
    HealthService.instance.hasPermissionsOverride = false; // Initially revoked

    await tester.pumpWidget(buildTestWidget(
      theme: ThemeData(platform: TargetPlatform.android),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Permission required • Grant access in system settings'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    // User went to system settings and granted permissions
    HealthService.instance.hasPermissionsOverride = true;

    // Application resumes
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    // Automatically transitions to active connected state upon resume
    expect(find.text('Active • Synced with Wear OS, Apple Watch & health apps'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.text('Sync Now'), findsOneWidget);
  });
}
