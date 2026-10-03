import 'package:flutter/foundation.dart';

/// Minimal view of the signed-in user.
@immutable
class AuthUser {
  const AuthUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;
}

/// A friendly, user-facing authentication error.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Authentication contract. Antigravity swaps the mock for Supabase Auth.
abstract class AuthRepository {
  AuthUser? get currentUser;

  /// Emits the current user first, then every change (null = signed out).
  Stream<AuthUser?> authStateChanges();

  Future<void> signInWithEmail({required String email, required String password});

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Permanently deletes the account and all of its data.
  Future<void> deleteAccount();
}
