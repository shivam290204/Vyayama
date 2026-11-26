import 'package:flutter/foundation.dart';

/// Minimal view of the signed-in user.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;
}

/// Result of an email sign-up request.
enum SignUpOutcome {
  /// User immediately received an active session and is signed in.
  signedIn,

  /// Account created (or pending verification); email confirmation required.
  confirmationRequired,
}

/// A friendly, user-facing authentication error.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Raised when email/password sign-in is blocked pending email confirmation.
class EmailNotConfirmedFailure extends AuthFailure {
  const EmailNotConfirmedFailure(this.email, super.message);

  final String email;
}

/// Authentication contract. Antigravity swaps the mock for Supabase Auth.
abstract class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user first, then every change (null = signed out).
  Stream<AuthUser?> authStateChanges();

  /// Emits when a password recovery link opens the app.
  Stream<bool> get onPasswordRecovery => const Stream.empty();

  /// Emits friendly error messages from asynchronous auth flows (e.g. OAuth callbacks).
  Stream<String> get authErrors => const Stream.empty();

  Future<void> signInWithEmail({required String email, required String password});

  Future<SignUpOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? username,
  });

  Future<void> resendConfirmationEmail(String email);

  Future<void> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  /// Updates the signed-in (or recovery) user's password.
  Future<void> updatePassword(String newPassword);

  Future<void> signOut();

  /// Permanently deletes the account and all of its data.
  Future<void> deleteAccount();
}
