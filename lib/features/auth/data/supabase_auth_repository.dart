import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy/core/services/background_sync_service.dart';
import 'package:fitbuddy/core/services/push_notification_service.dart';
import 'package:fitbuddy/core/services/secure_auth_storage.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({
    supa.GoTrueClient? authClient,
    String? googleServerClientId,
    Future<void> Function(String serverClientId)? nativeGoogleSignInOverride,
    Future<bool> Function()? oauthSignInOverride,
  })  : _authClientOverride = authClient,
        _googleServerClientIdOverride = googleServerClientId,
        _nativeGoogleSignInOverride = nativeGoogleSignInOverride,
        _oauthSignInOverride = oauthSignInOverride;

  final supa.GoTrueClient? _authClientOverride;
  final String? _googleServerClientIdOverride;
  final Future<void> Function(String serverClientId)?
      _nativeGoogleSignInOverride;
  final Future<bool> Function()? _oauthSignInOverride;

  supa.GoTrueClient get _client =>
      _authClientOverride ?? supa.Supabase.instance.client.auth;
  final _recoveryController = StreamController<bool>.broadcast();
  final _authErrorController = StreamController<String>.broadcast();
  final _authOverrideController = StreamController<AuthUser?>.broadcast();

  @override
  Stream<bool> get onPasswordRecovery => _recoveryController.stream;

  @override
  Stream<String> get authErrors => _authErrorController.stream;

  static AuthUser? _cachedUser;
  static bool _signedOut = false;
  static bool _googleSignInInitialized = false;
  static const Duration _authTimeout = Duration(seconds: 12);
  static const String _oauthRedirectUrl = 'io.vyayama.fitbuddy://login-callback';

  static Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    final serverClientId = Env.googleWebClientId;
    if (serverClientId.isNotEmpty) {
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId,
      );
      _googleSignInInitialized = true;
    }
  }

  AuthUser _mapUser(supa.User user) {
    final rawName =
        (user.userMetadata?['name'] ?? user.userMetadata?['full_name'])
            as String?;
    final mapped = AuthUser(
      id: user.id,
      email: user.email ?? '',
      displayName: (rawName != null && rawName.trim().isNotEmpty)
          ? rawName.trim()
          : null,
    );
    _cacheUser(mapped);
    return mapped;
  }

  void _cacheUser(AuthUser user) {
    _signedOut = false;
    _cachedUser = user;
    if (_authClientOverride != null) return;
    final session = _client.currentSession;
    SecureAuthStorage.instance.saveSession(
      accessToken: session?.accessToken ?? '',
      refreshToken: session?.refreshToken,
      userId: user.id,
      email: user.email,
      displayName: user.displayName,
    );
  }

  Future<void> _clearCachedUser() async {
    _cachedUser = null;
    if (_authClientOverride != null) return;
    try {
      await BackgroundSyncService.instance.clearUser();
    } catch (_) {}
    try {
      await SecureAuthStorage.instance.clearSession();
    } catch (_) {}
  }

  @override
  AuthUser? get currentUser {
    if (_signedOut) return null;
    final user = _client.currentUser;
    if (user != null) return _mapUser(user);

    // Fallback: check in-memory cache
    if (_cachedUser != null) return _cachedUser;
    return null;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    final controller = StreamController<AuthUser?>();
    StreamSubscription<supa.AuthState>? sub;
    StreamSubscription<AuthUser?>? overrideSub;
    var closed = false;

    void emit(AuthUser? user) {
      if (!closed && !controller.isClosed) {
        controller.add(user);
      }
    }

    Future<void> start() async {
      // 1. Immediately yield current or cached user so stream never blocks when offline
      var current = currentUser;
      if (!_signedOut && current == null) {
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
      emit(current);

      overrideSub = _authOverrideController.stream.listen(emit);

      // 2. Stream subsequent auth state changes from Supabase
      sub = _client.onAuthStateChange.listen(
        (event) async {
          if (event.event == supa.AuthChangeEvent.passwordRecovery) {
            _recoveryController.add(true);
          }
          if (event.session != null) {
            if (_signedOut &&
                event.event != supa.AuthChangeEvent.signedIn &&
                event.event != supa.AuthChangeEvent.passwordRecovery) {
              return;
            }
            _signedOut = false;
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString(
                'cached_auth_access_token',
                event.session!.accessToken,
              );
              if (event.session!.refreshToken != null) {
                prefs.setString(
                  'cached_auth_refresh_token',
                  event.session!.refreshToken!,
                );
              }
              if (event.session!.user.id.isNotEmpty) {
                prefs.setString(
                  'last_signed_in_user_id',
                  event.session!.user.id,
                );
              }
            }).catchError((_) {});
            final mapped = _mapUser(event.session!.user);
            unawaited(
              BackgroundSyncService.instance.syncCurrentUserId(mapped.id),
            );
            emit(mapped);
          } else if (event.event == supa.AuthChangeEvent.signedOut) {
            _signedOut = true;
            await _clearCachedUser();
            emit(null);
          } else if (!_signedOut) {
            // Offline or initial session loading with temporary null session:
            // DO NOT log the user out! Keep cached session if available.
            if (_cachedUser != null) {
              emit(_cachedUser);
            } else {
              try {
                final prefs = await SharedPreferences.getInstance();
                final id = prefs.getString('last_signed_in_user_id');
                if (id != null && id.isNotEmpty) {
                  final email = prefs.getString('last_signed_in_user_email') ?? '';
                  final name = prefs.getString('last_signed_in_user_name');
                  _cachedUser = AuthUser(id: id, email: email, displayName: name);
                  emit(_cachedUser);
                  return;
                }
              } catch (_) {}
              emit(null);
            }
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('[SupabaseAuthRepository] auth stream error: $error');
          if (!_authErrorController.isClosed) {
            final msg = error is supa.AuthException
                ? _friendlyAuthErrorMessage(error)
                : 'Sign-in could not be completed. Please try again.';
            _authErrorController.add(msg);
          }
        },
      );
    }

    controller.onCancel = () {
      closed = true;
      sub?.cancel();
      overrideSub?.cancel();
    };

    unawaited(start());
    return controller.stream;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    try {
      final res = await _client
          .signInWithPassword(email: trimmedEmail, password: password)
          .timeout(_authTimeout);
      _signedOut = false;
      if (res.user != null) {
        _authOverrideController.add(_mapUser(res.user!));
      }
    } on TimeoutException {
      throw const AuthFailure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } on supa.AuthException catch (e) {
      if (_isEmailNotConfirmed(e)) {
        throw EmailNotConfirmedFailure(
          trimmedEmail,
          _friendlyAuthErrorMessage(e),
        );
      }
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw const AuthFailure('Failed to sign in. Please try again.');
    }
  }

  @override
  Future<SignUpOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      final cleanUsername = (username != null && username.trim().isNotEmpty)
          ? username.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '')
          : null;

      final res = await _client
          .signUp(
            email: email.trim(),
            password: password,
            emailRedirectTo: kIsWeb ? null : _oauthRedirectUrl,
            data: {
              'name': name,
              if (cleanUsername != null) 'username': cleanUsername,
            },
          )
          .timeout(_authTimeout);
      if (res.session != null && res.user != null) {
        _signedOut = false;
        _authOverrideController.add(_mapUser(res.user!));
        return SignUpOutcome.signedIn;
      }
      return SignUpOutcome.confirmationRequired;
    } on TimeoutException {
      throw const AuthFailure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw const AuthFailure('Failed to sign up. Please try again.');
    }
  }

  @override
  Future<void> resendConfirmationEmail(String email) async {
    final trimmedEmail = email.trim();
    try {
      await _client
          .resend(
            email: trimmedEmail,
            type: supa.OtpType.signup,
            emailRedirectTo: kIsWeb ? null : _oauthRedirectUrl,
          )
          .timeout(_authTimeout);
    } on TimeoutException {
      throw const AuthFailure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (_) {
      throw const AuthFailure('Failed to resend verification email.');
    }
  }

  static bool _isEmailNotConfirmed(supa.AuthException e) {
    final msg = e.message.toLowerCase();
    return e.code == 'email_not_confirmed' || msg.contains('email not confirmed');
  }

  static String _friendlyAuthErrorMessage(supa.AuthException e) {
    if (_isEmailNotConfirmed(e)) {
      return 'Please verify your email first. Check your inbox (and spam folder), or resend the confirmation email.';
    }
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') ||
        msg.contains('over_email_send_rate_limit')) {
      return 'Email rate limit reached by server. Please wait a moment or try again shortly.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered')) {
      return 'An account with this email already exists. Please log in.';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('provider is not enabled') ||
        msg.contains('oauth_provider_not_supported')) {
      return 'Google sign-in is not enabled on the server.';
    }
    return e.message;
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final serverClientId =
          _googleServerClientIdOverride ?? Env.googleWebClientId;
      if (!kIsWeb && serverClientId.isNotEmpty) {
        final didFinish = await _tryNativeGoogleSignIn(serverClientId);
        if (didFinish) return;
      }

      await _signInWithGoogleOAuth();
    } on TimeoutException {
      throw const AuthFailure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw const AuthFailure('Failed to sign in with Google.');
    }
  }

  /// Attempts native Google Sign-In. Returns `true` when authentication either
  /// completed or was intentionally canceled by the user; returns `false` when
  /// native Sign-In is misconfigured/unavailable so browser OAuth can run.
  Future<bool> _tryNativeGoogleSignIn(String serverClientId) async {
    try {
      if (_nativeGoogleSignInOverride != null) {
        await _nativeGoogleSignInOverride(serverClientId);
        return true;
      }
      await _ensureGoogleSignInInitializedFor(serverClientId)
          .timeout(_authTimeout);
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint(
          '[SupabaseAuthRepository] Native Google ID token missing; falling back to browser OAuth.',
        );
        return false;
      }

      String? accessToken;
      try {
        final authz = await account.authorizationClient
            .authorizationForScopes(['email'])
            .timeout(const Duration(seconds: 4));
        if (authz != null && authz.accessToken.isNotEmpty) {
          accessToken = authz.accessToken;
        }
      } catch (_) {
        // Optional: Supabase verifies Google idToken without an access token.
      }

      final res = await _client
          .signInWithIdToken(
            provider: supa.OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          )
          .timeout(_authTimeout);
      _signedOut = false;
      if (res.user != null) {
        _authOverrideController.add(_mapUser(res.user!));
      }
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return true;
      }
      debugPrint(
        '[SupabaseAuthRepository] Native Google Sign-In unavailable (${e.code.name}: ${e.description}); falling back to browser OAuth.',
      );
      return false;
    } on supa.AuthException catch (e) {
      debugPrint(
        '[SupabaseAuthRepository] Native Google token rejected (${e.message}); falling back to browser OAuth.',
      );
      return false;
    } on TimeoutException catch (e) {
      debugPrint(
        '[SupabaseAuthRepository] Native Google Sign-In timed out ($e); falling back to browser OAuth.',
      );
      return false;
    } catch (e) {
      debugPrint(
        '[SupabaseAuthRepository] Native Google Sign-In failed ($e); falling back to browser OAuth.',
      );
      return false;
    }
  }

  Future<void> _signInWithGoogleOAuth() async {
    _signedOut = false;
    final launched = _oauthSignInOverride != null
        ? await _oauthSignInOverride().timeout(_authTimeout)
        : await _client
            .signInWithOAuth(
              supa.OAuthProvider.google,
              redirectTo: kIsWeb ? null : _oauthRedirectUrl,
            )
            .timeout(_authTimeout);
    if (!launched) {
      throw const AuthFailure(
        'Could not open a browser for Google sign-in. Please check your default browser app.',
      );
    }
  }

  static Future<void> _ensureGoogleSignInInitializedFor(
    String serverClientId,
  ) async {
    if (_googleSignInInitialized) return;
    if (serverClientId.isNotEmpty) {
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId,
      );
      _googleSignInInitialized = true;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _client
          .resetPasswordForEmail(
            email,
            redirectTo: kIsWeb ? null : 'io.vyayama.fitbuddy://reset-password',
          )
          .timeout(_authTimeout);
    } on TimeoutException {
      throw const AuthFailure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (e) {
      throw AuthFailure('Failed to send reset email.');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client
          .updateUser(supa.UserAttributes(password: newPassword))
          .timeout(_authTimeout);
    } on TimeoutException {
      throw const AuthFailure(
        'Connection timed out. Please check your internet connection and try again.',
      );
    } on supa.AuthException catch (e) {
      throw AuthFailure(_friendlyAuthErrorMessage(e));
    } catch (_) {
      throw const AuthFailure('Failed to update password.');
    }
  }

  @override
  Future<void> signOut() async {
    _signedOut = true;
    _cachedUser = null;
    _authOverrideController.add(null);

    // Best-effort remote push/Google cleanup capped at 2s so Log out never hangs
    final cleanupTasks = <Future<void>>[
      PushNotificationService.instance
          .unregisterDeviceToken()
          .timeout(const Duration(seconds: 2))
          .catchError((_) {}),
      if (!kIsWeb && Env.googleWebClientId.isNotEmpty)
        () async {
          await _ensureGoogleSignInInitialized()
              .timeout(const Duration(seconds: 2));
          await GoogleSignIn.instance
              .signOut()
              .timeout(const Duration(seconds: 2));
        }()
            .catchError((_) {}),
    ];
    try {
      await Future.wait(cleanupTasks);
    } catch (_) {}

    await _clearCachedUser();

    try {
      await _client
          .signOut(scope: supa.SignOutScope.local)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    if (Env.isSupabaseConfigured) {
      try {
        final sessionKey =
            'sb-${Uri.parse(Env.supabaseUrl).host.split(".").first}-auth-token';
        await SupabaseSecureLocalStorage(persistSessionKey: sessionKey)
            .removePersistedSession();
      } catch (_) {}
    }

    _authOverrideController.add(null);
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
