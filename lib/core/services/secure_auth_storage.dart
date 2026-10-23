import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure token and session credentials storage backed by
/// Android KeyStore (EncryptedSharedPreferences) and iOS Keychain.
class SecureAuthStorage {
  SecureAuthStorage._();
  static final SecureAuthStorage instance = SecureAuthStorage._();

  static const _kAccessToken = 'cached_auth_access_token';
  static const _kRefreshToken = 'cached_auth_refresh_token';
  static const _kUserId = 'last_signed_in_user_id';
  static const _kUserEmail = 'last_signed_in_user_email';
  static const _kUserName = 'last_signed_in_user_name';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Saves session credentials securely in encrypted hardware-backed storage.
  /// Also cleans up any legacy plaintext keys from SharedPreferences.
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required String userId,
    String? email,
    String? displayName,
  }) async {
    try {
      await _storage.write(key: _kAccessToken, value: accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _storage.write(key: _kRefreshToken, value: refreshToken);
      }
      await _storage.write(key: _kUserId, value: userId);
      if (email != null && email.isNotEmpty) {
        await _storage.write(key: _kUserEmail, value: email);
      }
      if (displayName != null && displayName.isNotEmpty) {
        await _storage.write(key: _kUserName, value: displayName);
      }
    } catch (e) {
      debugPrint('[SecureAuthStorage] write error: $e');
    }

    // Purge legacy plaintext credentials from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kUserEmail);
      // Keep only non-sensitive user_id for fast offline route gating if needed
      await prefs.setString(_kUserId, userId);
    } catch (_) {}
  }

  /// Retrieves the cached access token.
  Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _kAccessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[SecureAuthStorage] read accessToken error: $e');
    }

    // One-time migration fallback from SharedPreferences if upgraded
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_kAccessToken);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: _kAccessToken, value: legacy);
        await prefs.remove(_kAccessToken);
        return legacy;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the cached refresh token.
  Future<String?> getRefreshToken() async {
    try {
      final token = await _storage.read(key: _kRefreshToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[SecureAuthStorage] read refreshToken error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_kRefreshToken);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: _kRefreshToken, value: legacy);
        await prefs.remove(_kRefreshToken);
        return legacy;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the cached user ID.
  Future<String?> getUserId() async {
    try {
      final id = await _storage.read(key: _kUserId);
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kUserId);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the cached user email.
  Future<String?> getUserEmail() async {
    try {
      final email = await _storage.read(key: _kUserEmail);
      if (email != null && email.isNotEmpty) return email;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(_kUserEmail);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: _kUserEmail, value: legacy);
        await prefs.remove(_kUserEmail);
        return legacy;
      }
    } catch (_) {}
    return null;
  }

  /// Clears all stored auth tokens and sensitive metadata.
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _kAccessToken);
      await _storage.delete(key: _kRefreshToken);
      await _storage.delete(key: _kUserId);
      await _storage.delete(key: _kUserEmail);
      await _storage.delete(key: _kUserName);
    } catch (e) {
      debugPrint('[SecureAuthStorage] delete error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kUserEmail);
      await prefs.remove(_kUserName);
      await prefs.remove(_kUserId);
    } catch (_) {}
  }
}

/// Secure implementation of [LocalStorage] for [Supabase.initialize]
/// backed by Android KeyStore (EncryptedSharedPreferences) and iOS Keychain.
class SupabaseSecureLocalStorage extends LocalStorage {
  SupabaseSecureLocalStorage({
    this.persistSessionKey = 'sb_auth_session',
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final String persistSessionKey;
  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    try {
      final token = await _storage.read(key: persistSessionKey);
      if (token != null && token.isNotEmpty) return true;
    } catch (e) {
      debugPrint('[SupabaseSecureLocalStorage] hasAccessToken error: $e');
    }

    // Check for legacy migration from plaintext SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(persistSessionKey);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> accessToken() async {
    try {
      final token = await _storage.read(key: persistSessionKey);
      if (token != null && token.isNotEmpty) return token;
    } catch (e) {
      debugPrint('[SupabaseSecureLocalStorage] accessToken read error: $e');
    }

    // One-time legacy migration from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy != null && legacy.isNotEmpty) {
        await _storage.write(key: persistSessionKey, value: legacy);
        await prefs.remove(persistSessionKey);
        return legacy;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (e) {
      debugPrint(
          '[SupabaseSecureLocalStorage] removePersistedSession error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(persistSessionKey);
    } catch (_) {}
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: persistSessionKey, value: persistSessionString);
    } catch (e) {
      debugPrint('[SupabaseSecureLocalStorage] persistSession error: $e');
    }

    // Ensure plaintext copy in SharedPreferences is eliminated
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(persistSessionKey);
    } catch (_) {}
  }
}

/// Secure PKCE storage for Supabase auth flow
class SupabaseSecureGotrueAsyncStorage extends GotrueAsyncStorage {
  SupabaseSecureGotrueAsyncStorage({
    FlutterSecureStorage? storage,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) return value;
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(key);
      if (legacy != null) {
        await _storage.write(key: key, value: legacy);
        await prefs.remove(key);
        return legacy;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  @override
  Future<void> removeItem({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
  }
}

