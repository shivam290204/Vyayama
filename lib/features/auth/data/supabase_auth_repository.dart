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
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to sign in. Please try again.');
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final cleanUsername = (username != null && username.trim().isNotEmpty)
          ? username.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '')
          : null;

      await _client.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          if (cleanUsername != null) 'username': cleanUsername,
        },
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to sign up. Please try again.');
    }
  }

  static String _friendlyAuthErrorMessage(supa.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
      return 'Email rate limit reached by server. Please wait a moment or try again shortly.';
    }
    if (msg.contains('user already registered') || msg.contains('already registered')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    return e.message;
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.signInWithOAuth(
        supa.OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.vyayama.fitbuddy://login-callback',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to sign in with Google.');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.resetPasswordForEmail(email);
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
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
    final userId = _client.currentUser?.id;
    if (userId == null) throw const AuthFailure('Not signed in.');

    try {
      final supaClient = supa.Supabase.instance.client;

      // 1. Clean up user's snap images from storage (best-effort)
      try {
        final res = await supaClient
            .from('snaps')
            .select('image_path')
            .eq('sender_id', userId);

        final paths = (res as List)
            .map((r) => r['image_path'] as String?)
            .whereType<String>()
            .toList();

        if (paths.isNotEmpty) {
          await supaClient.storage.from('snaps').remove(paths);
        }
      } catch (_) {
        // Storage cleanup is best-effort before SQL cascade
      }

      // 2. Call delete_my_account() RPC which cascades all tables and deletes auth user
      await supaClient.rpc('delete_my_account');

      // 3. Clear local session
      await signOut();
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to delete account: $e');
    }
  }
}
