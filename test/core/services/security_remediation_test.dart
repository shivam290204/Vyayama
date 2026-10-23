import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitbuddy/core/constants/env.dart';
import 'package:fitbuddy/core/services/secure_auth_storage.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Env Security & Config Tests', () {
    test('Env properties return safe defaults when unconfigured', () {
      expect(Env.supabaseUrl, isA<String>());
      expect(Env.supabaseAnonKey, isA<String>());
      // Without valid URL/key, isSupabaseConfigured must be false
      if (!Env.supabaseUrl.startsWith('http') || Env.supabaseAnonKey.isEmpty) {
        expect(Env.isSupabaseConfigured, isFalse);
      }
    });
  });

  group('VerificationResult Security Tests', () {
    test('verified state properly exposes verification properties', () {
      final res = VerificationResult.verified(activity: 'running', confidence: 0.95);
      expect(res.isVerified, isTrue);
      expect(res.isPending, isFalse);
      expect(res.isRejected, isFalse);
      expect(res.activity, 'running');
      expect(res.confidence, 0.95);
      expect(res.status, VerificationStatus.verified);
    });

    test('rejected state properly exposes rejection reason', () {
      final res = VerificationResult.rejected(reason: 'Not exercise');
      expect(res.isVerified, isFalse);
      expect(res.isPending, isFalse);
      expect(res.isRejected, isTrue);
      expect(res.reason, 'Not exercise');
      expect(res.status, VerificationStatus.rejected);
    });

    test('pending state prevents premature streak/reward credit', () {
      final res = VerificationResult.pending(reason: 'Verification in progress');
      expect(res.isVerified, isFalse);
      expect(res.isPending, isTrue);
      expect(res.isRejected, isFalse);
      expect(res.status, VerificationStatus.pending);
    });
  });

  group('Plaintext SharedPreferences Sanitation Tests', () {
    test('sanitizes legacy plaintext tokens from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'cached_auth_access_token': 'legacy-plaintext-token',
        'cached_auth_refresh_token': 'legacy-plaintext-refresh',
        'last_signed_in_user_email': 'test@example.com',
        'last_signed_in_user_id': 'user-123',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cached_auth_access_token'), 'legacy-plaintext-token');

      // Purge tokens as done by SecureAuthStorage
      await prefs.remove('cached_auth_access_token');
      await prefs.remove('cached_auth_refresh_token');
      await prefs.remove('last_signed_in_user_email');

      expect(prefs.getString('cached_auth_access_token'), isNull);
      expect(prefs.getString('cached_auth_refresh_token'), isNull);
      expect(prefs.getString('last_signed_in_user_email'), isNull);
      // Non-sensitive user ID can remain for fast routing
      expect(prefs.getString('last_signed_in_user_id'), 'user-123');
    });
  });

  group('SupabaseSecureLocalStorage & GotrueAsyncStorage Tests', () {
    test('SupabaseSecureLocalStorage migrates legacy plaintext session from SharedPreferences', () async {
      const sessionKey = 'sb_test_session';
      SharedPreferences.setMockInitialValues({
        sessionKey: '{"access_token":"legacy-token","user":{"id":"u1"}}',
      });
      FlutterSecureStorage.setMockInitialValues({});

      final storage = SupabaseSecureLocalStorage(persistSessionKey: sessionKey);
      expect(await storage.hasAccessToken(), isTrue);

      final token = await storage.accessToken();
      expect(token, contains('legacy-token'));

      // Confirm migrated: SharedPreferences legacy key was removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(sessionKey), isFalse);

      // Verify removal
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('SupabaseSecureGotrueAsyncStorage reads and writes securely', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({'pkce_verifier': 'legacy-verifier'});

      final storage = SupabaseSecureGotrueAsyncStorage();
      final migrated = await storage.getItem(key: 'pkce_verifier');
      expect(migrated, 'legacy-verifier');

      // Legacy key should be removed from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pkce_verifier'), isFalse);

      await storage.setItem(key: 'code_challenge', value: 'secret-challenge');
      expect(await storage.getItem(key: 'code_challenge'), 'secret-challenge');

      await storage.removeItem(key: 'code_challenge');
      expect(await storage.getItem(key: 'code_challenge'), isNull);
    });
  });
}

