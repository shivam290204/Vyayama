import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy/core/services/background_sync_service.dart';
import 'package:fitbuddy/core/services/push_notification_service.dart';
import 'package:fitbuddy/core/services/secure_auth_storage.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class SupabaseAuthRepository implements AuthRepository {
  final _client = supa.Supabase.instance.client.auth;

  static AuthUser? _cachedUser;

  AuthUser _mapUser(supa.User user) {
    final mapped = AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['name'] as String?,
    );
    _cacheUser(mapped);
    return mapped;
  }

  static void _cacheUser(AuthUser user) {
    _cachedUser = user;
    final session = supa.Supabase.instance.client.auth.currentSession;
    SecureAuthStorage.instance.saveSession(
      accessToken: session?.accessToken ?? '',
      refreshToken: session?.refreshToken,
      userId: user.id,
      email: user.email,
      displayName: user.displayName,
    );
  }

  static void _clearCachedUser() {
    _cachedUser = null;
    BackgroundSyncService.instance.clearUser();
    SecureAuthStorage.instance.clearSession();
  }

  @override
  AuthUser? get currentUser {
    final user = _client.currentUser;
    if (user != null) return _mapUser(user);

    // Fallback: check in-memory cache
    if (_cachedUser != null) return _cachedUser;
    return null;
  }

  @override
  Stream<AuthUser?> authStateChanges() async* {
    // 1. Immediately yield current or cached user so stream never blocks when offline
    var current = currentUser;
    if (current == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final id = prefs.getString('last_signed_in_user_id');
        if (id != null && id.isNotEmpty) {
          final email = prefs.getString('last_signed_in_user_email') ?? '';
          final name = prefs.getString('last_signed_in_user_name');
          current = AuthUser(id: id, email: email, displayName: name);
          _cachedUser = current;
        }
      } catch (_) {}
    }
    yield current;

    // 2. Stream subsequent auth state changes from Supabase
    await for (final event in _client.onAuthStateChange) {
      if (event.session != null) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('cached_auth_access_token', event.session!.accessToken);
          if (event.session!.refreshToken != null) {
            prefs.setString('cached_auth_refresh_token', event.session!.refreshToken!);
          }
          if (event.session!.user.id.isNotEmpty) {
            prefs.setString('last_signed_in_user_id', event.session!.user.id);
          }
        }).catchError((_) {});
        final mapped = _mapUser(event.session!.user);
        BackgroundSyncService.instance.syncCurrentUserId(mapped.id);
        yield mapped;
      } else if (event.event == supa.AuthChangeEvent.signedOut) {
        _clearCachedUser();
        yield null;
      } else {
        // Offline or initial session loading with temporary null session:
        // DO NOT log the user out! Keep cached session if available.
        if (_cachedUser != null) {
          yield _cachedUser;
        } else {
          try {
            final prefs = await SharedPreferences.getInstance();
            final id = prefs.getString('last_signed_in_user_id');
            if (id != null && id.isNotEmpty) {
              final email = prefs.getString('last_signed_in_user_email') ?? '';
              final name = prefs.getString('last_signed_in_user_name');
              _cachedUser = AuthUser(id: id, email: email, displayName: name);
              yield _cachedUser;
              continue;
            }
          } catch (_) {}
          yield null;
        }
      }
    }
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
      await _client.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : 'io.vyayama.fitbuddy://reset-password',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to send reset email.');
    }
  }

  @override
  Future<void> signOut() async {
    _clearCachedUser();
    try {
      await PushNotificationService.instance.unregisterDeviceToken();
    } catch (_) {}
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

      // 1. Clean up user's snap images from storage via the official Storage API
      try {
        final res = await supaClient
            .from('snaps')
            .select('image_path')
            .eq('sender_id', userId);

        final paths = (res as List)
            .map((r) => r['image_path'] as String?)
            .whereType<String>()
            .toSet();

        // Also check files listed under user prefix in 'snaps' bucket
        try {
          final userFiles = await supaClient.storage.from('snaps').list(path: userId);
          for (final f in userFiles) {
            paths.add('$userId/${f.name}');
          }
        } catch (_) {}

        if (paths.isNotEmpty) {
          await supaClient.storage.from('snaps').remove(paths.toList());
        }
      } catch (e) {
        debugPrint('[deleteAccount] storage API cleanup warning: $e');
      }

      // 2. Call delete_my_account() RPC which cascades all tables and deletes auth user
      await supaClient.rpc('delete_my_account');

      // 3. Clear local hardware-backed and shared credentials
      await SecureAuthStorage.instance.clearSession();
      await signOut();
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to delete account: $e');
    }
  }
}
