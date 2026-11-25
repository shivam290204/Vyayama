import 'package:fitbuddy/core/router/app_router.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/auth/data/mock_auth_repository.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/auth/screens/reset_password_screen.dart';
import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:fitbuddy/features/friends/screens/user_profile_screen.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('appRedirect link allowances', () {
    test('allows unauthenticated access to /reset-password, /invite/:id, /u/:id',
        () {
      const noAuth = AsyncData<AuthUser?>(null);
      const noProfile = AsyncData<Profile?>(null);

      expect(
        appRedirect(
          location: AppRoutes.resetPassword,
          auth: noAuth,
          profile: noProfile,
        ),
        isNull,
      );
      expect(
        appRedirect(
          location: '/invite/alex123',
          auth: noAuth,
          profile: noProfile,
        ),
        isNull,
      );
      expect(
        appRedirect(
          location: '/u/alex123',
          auth: noAuth,
          profile: noProfile,
        ),
        isNull,
      );
    });
  });

  group('parseProfileIdentifier', () {
    test('extracts username/id from web and scheme invite/profile links', () {
      expect(
        parseProfileIdentifier('https://vyayama.app/invite/alex123'),
        'alex123',
      );
      expect(
        parseProfileIdentifier('https://invite.vyayama.example/u/user-42'),
        'user-42',
      );
      expect(parseProfileIdentifier('vyayama://u/maya_fit'), 'maya_fit');
    });

    test('does not treat password recovery or unknown URLs as profile identifier',
        () {
      expect(
        parseProfileIdentifier('io.vyayama.fitbuddy://reset-password'),
        isNull,
      );
      expect(
        parseProfileIdentifier('https://example.com/some/other/path'),
        isNull,
      );
    });
  });

  group('MockAuthRepository password reset', () {
    test('throws when signed out and updates password when signed in',
        () async {
      final repo = MockAuthRepository();
      await expectLater(
        repo.updatePassword('NewPass123!'),
        throwsA(isA<AuthFailure>()),
      );

      await repo.signInWithEmail(
        email: 'demo@vyayama.app',
        password: 'vyayama123',
      );
      await repo.updatePassword('NewPass123!');
      await repo.signOut();

      await expectLater(
        repo.signInWithEmail(
          email: 'demo@vyayama.app',
          password: 'vyayama123',
        ),
        throwsA(isA<AuthFailure>()),
      );

      await repo.signInWithEmail(
        email: 'demo@vyayama.app',
        password: 'NewPass123!',
      );
      expect(repo.currentUser?.email, 'demo@vyayama.app');
      repo.dispose();
    });
  });

  group('ResetPasswordScreen & dark theme token smoke checks', () {
    testWidgets('validates mismatch and updates password to navigate home',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockAuth = MockAuthRepository();
      addTearDown(mockAuth.dispose);
      await tester.runAsync(
        () => mockAuth.signInWithEmail(
          email: 'demo@vyayama.app',
          password: 'vyayama123',
        ),
      );

      final router = GoRouter(
        initialLocation: AppRoutes.resetPassword,
        routes: [
          GoRoute(
            path: AppRoutes.resetPassword,
            builder: (_, __) => const ResetPasswordScreen(),
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) => const Scaffold(body: Text('HOME_DEST')),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, __) => const Scaffold(body: Text('LOGIN_DEST')),
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
            darkTheme: AppTheme.dark(useGoogleFonts: false),
            themeMode: ThemeMode.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set a new password'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'StrongPass123!');
      await tester.enterText(fields.at(1), 'DifferentPass123!');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);

      await tester.enterText(fields.at(1), 'StrongPass123!');
      await tester.ensureVisible(find.text('Update Password'));
      await tester.tap(find.text('Update Password'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('HOME_DEST'), findsOneWidget);
    });

    testWidgets('UserProfileScreen renders cleanly under dark theme tokens',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(useGoogleFonts: false),
            darkTheme: AppTheme.dark(useGoogleFonts: false),
            themeMode: ThemeMode.dark,
            home: const UserProfileScreen(identifier: 'maya_fit'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Friend'), findsOneWidget);
    });
  });
}
