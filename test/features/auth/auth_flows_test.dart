import 'dart:async';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/auth/data/supabase_auth_repository.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/auth/screens/login_screen.dart';
import 'package:fitbuddy/features/auth/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class _FakeAuthRepository implements AuthRepository {
  final _authController = StreamController<AuthUser?>.broadcast();
  final _errorsController = StreamController<String>.broadcast();

  AuthUser? _current;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastResendEmail;
  AuthFailure? nextLoginFailure;
  SignUpOutcome nextSignUpOutcome = SignUpOutcome.signedIn;

  void emitAuthError(String message) => _errorsController.add(message);

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _authController.stream;
  }

  @override
  Stream<bool> get onPasswordRecovery => const Stream.empty();

  @override
  Stream<String> get authErrors => _errorsController.stream;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    if (nextLoginFailure != null) {
      throw nextLoginFailure!;
    }
    _current = AuthUser(id: 'u-email', email: email, displayName: 'Email User');
    _authController.add(_current);
  }

  @override
  Future<SignUpOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? username,
  }) async {
    if (nextSignUpOutcome == SignUpOutcome.confirmationRequired) {
      return SignUpOutcome.confirmationRequired;
    }
    _current = AuthUser(id: 'u-new', email: email, displayName: name);
    _authController.add(_current);
    return SignUpOutcome.signedIn;
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    lastResendEmail = email;
  }

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> signOut() async {
    _current = null;
    _authController.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    _current = null;
    _authController.add(null);
  }

  Future<void> dispose() async {
    await _authController.close();
    await _errorsController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupabaseAuthRepository.signInWithGoogle fallback', () {
    late supa.GoTrueClient testClient;

    setUp(() {
      testClient = supa.GoTrueClient(
        url: 'https://example.supabase.co/auth/v1',
        autoRefreshToken: false,
      );
    });

    tearDown(() {
      testClient.dispose();
    });

    test('falls back to browser OAuth when native Google Sign-In fails',
        () async {
      var oauthCalls = 0;
      final repo = SupabaseAuthRepository(
        authClient: testClient,
        googleServerClientId: 'test-web-client-id.apps.googleusercontent.com',
        nativeGoogleSignInOverride: (_) async {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'DEVELOPER_ERROR: oauth_client missing',
          );
        },
        oauthSignInOverride: () async {
          oauthCalls++;
          return true;
        },
      );

      await repo.signInWithGoogle();
      expect(oauthCalls, 1);
    });

    test('does not fall back to browser OAuth when user cancels Google sheet',
        () async {
      var oauthCalls = 0;
      final repo = SupabaseAuthRepository(
        authClient: testClient,
        googleServerClientId: 'test-web-client-id.apps.googleusercontent.com',
        nativeGoogleSignInOverride: (_) async {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: 'User canceled',
          );
        },
        oauthSignInOverride: () async {
          oauthCalls++;
          return true;
        },
      );

      await repo.signInWithGoogle();
      expect(oauthCalls, 0);
    });

    test('throws AuthFailure when browser OAuth cannot open URL', () async {
      final repo = SupabaseAuthRepository(
        authClient: testClient,
        googleServerClientId: '',
        oauthSignInOverride: () async => false,
      );

      await expectLater(
        repo.signInWithGoogle(),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  group('LoginScreen & SignupScreen email flows', () {
    testWidgets(
        'LoginScreen accepts email input, shows resend action for unconfirmed email, and surfaces async authErrors',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeAuthRepository();
      addTearDown(repo.dispose);
      repo.nextLoginFailure = const EmailNotConfirmedFailure(
        'runner@example.com',
        'Please verify your email first.',
      );

      final router = GoRouter(
        initialLocation: AppRoutes.login,
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (_, __) => const LoginScreen(),
          ),
          GoRoute(
            path: AppRoutes.signup,
            builder: (_, __) => const SignupScreen(),
          ),
          GoRoute(
            path: AppRoutes.forgot,
            builder: (_, __) => const Scaffold(body: Text('FORGOT_SCREEN')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(
            theme: AppTheme.light(useGoogleFonts: false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        '  runner@example.com  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'StrongPass123!',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
      await tester.pumpAndSettle();

      expect(repo.lastLoginEmail, 'runner@example.com');
      expect(repo.lastLoginPassword, 'StrongPass123!');
      expect(find.text('Please verify your email first.'), findsWidgets);
      expect(find.text('Resend verification email'), findsOneWidget);

      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();
      expect(repo.lastResendEmail, 'runner@example.com');

      repo.emitAuthError('Google OAuth callback canceled.');
      await tester.pumpAndSettle();
      expect(find.text('Google OAuth callback canceled.'), findsWidgets);
    });

    testWidgets(
        'SignupScreen displays confirmation inbox state when email verification is required',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeAuthRepository()
        ..nextSignUpOutcome = SignUpOutcome.confirmationRequired;
      addTearDown(repo.dispose);

      final router = GoRouter(
        initialLocation: AppRoutes.signup,
        routes: [
          GoRoute(
            path: AppRoutes.signup,
            builder: (_, __) => const SignupScreen(),
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
          overrides: [authRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp.router(
            theme: AppTheme.light(useGoogleFonts: false),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Aarav',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'aarav@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'StrongPass123!',
      );

      final checkboxFinder = find.byType(Checkbox);
      await tester.ensureVisible(checkboxFinder);
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final signUpButton = find.widgetWithText(FilledButton, 'Sign up');
      await tester.ensureVisible(signUpButton);
      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('Resend verification email'), findsOneWidget);
      expect(find.text('Back to log in'), findsOneWidget);

      await tester.tap(find.text('Resend verification email'));
      await tester.pumpAndSettle();
      expect(repo.lastResendEmail, 'aarav@example.com');
    });
  });
}
