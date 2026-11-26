import 'dart:convert';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/auth/data/mock_auth_repository.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/settings/widgets/account_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedProfileRepository implements ProfileRepository {
  @override
  Future<Profile?> fetchProfile(String userId) async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return Profile(id: userId, name: 'Remote Name', onboardingCompleted: true);
  }

  @override
  Future<Profile> upsertProfile(Profile profile) async => profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AccountSection Log out signs out and navigates to login',
      (tester) async {
    final mockAuth = MockAuthRepository();
    addTearDown(mockAuth.dispose);
    await tester.runAsync(
      () => mockAuth.signInWithEmail(
        email: 'demo@vyayama.app',
        password: 'vyayama123',
      ),
    );

    final router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: [
        GoRoute(
          path: AppRoutes.settings,
          builder: (_, __) => const Scaffold(
            body: SingleChildScrollView(child: AccountSection()),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, __) => const Scaffold(body: Text('LOGIN_SCREEN')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(useGoogleFonts: false),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(mockAuth.currentUser, isNull);
    expect(find.text('LOGIN_SCREEN'), findsOneWidget);
  });

  test('CurrentProfileNotifier returns cached profile without waiting for slow remote',
      () async {
    const cached = Profile(
      id: kDemoUserId,
      name: 'Cached Athlete',
      onboardingCompleted: true,
    );
    SharedPreferences.setMockInitialValues({
      'cached_profile_$kDemoUserId': jsonEncode(cached.toJson()),
    });

    final mockAuth = MockAuthRepository();
    await mockAuth.signInWithEmail(
      email: 'demo@vyayama.app',
      password: 'vyayama123',
    );

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuth),
        profileRepositoryProvider.overrideWithValue(_DelayedProfileRepository()),
      ],
    );
    addTearDown(() {
      container.dispose();
      mockAuth.dispose();
    });

    // Wait for authStateProvider stream to emit signed-in user
    await container.read(authStateProvider.future);

    final sw = Stopwatch()..start();
    final loaded = await container.read(currentProfileProvider.future);
    sw.stop();

    expect(loaded?.name, 'Cached Athlete');
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('Account can sign out and sign back in without getting stuck', () async {
    final mockAuth = MockAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(mockAuth)],
    );
    addTearDown(() {
      container.dispose();
      mockAuth.dispose();
    });

    await mockAuth.signInWithEmail(
      email: 'demo@vyayama.app',
      password: 'vyayama123',
    );
    expect(mockAuth.currentUser?.id, kDemoUserId);

    await mockAuth.signOut();
    expect(mockAuth.currentUser, isNull);

    await mockAuth.signInWithEmail(
      email: 'demo@vyayama.app',
      password: 'vyayama123',
    );
    expect(mockAuth.currentUser?.id, kDemoUserId);
  });
}
