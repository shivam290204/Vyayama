import 'package:flutter/foundation.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class SupabaseAuthRepository implements AuthRepository {
  final _client = supa.Supabase.instance.client.auth;

  AuthUser _mapUser(supa.User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['name'] as String?,
    );
  }

  @override
  AuthUser? get currentUser {
    final user = _client.currentUser;
    return user != null ? _mapUser(user) : null;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.onAuthStateChange.map((event) {
      final user = event.session?.user;
      return user != null ? _mapUser(user) : null;
    });
  }

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {
    try {
      await _client.signInWithPassword(email: email, password: password);
    } on supa.AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Failed to sign in. Please try again.');
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _client.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Failed to sign up. Please try again.');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.signInWithOAuth(
        supa.OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.vyayama.fitbuddy://login-callback',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Failed to sign in with Google.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.resetPasswordForEmail(email);
    } on supa.AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw AuthFailure('Failed to send reset email.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (e) {
      throw AuthFailure('Failed to sign out.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      // Deleting a user requires admin privileges or an Edge Function.
      // For now, this is a placeholder or calls a custom RPC.
      throw const AuthFailure('Account deletion requires contacting support.');
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }
}
