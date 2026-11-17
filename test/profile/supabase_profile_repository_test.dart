import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/data/profile_repository.dart';
import 'package:fitbuddy/features/profile/data/supabase_profile_repository.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/widgets/edit_profile_form.dart';

class TestHttpClient extends http.BaseClient {
  TestHttpClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  const testUserId = 'test-user-123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('SupabaseProfileRepository Profile Update Tests', () {
    test('1. Successful profile update issues PATCH, excludes protected columns, and updates local cache', () async {
      http.BaseRequest? capturedRequest;
      Map<String, dynamic>? capturedPayload;

      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          capturedRequest = req;
          if (req is http.Request) {
            capturedPayload = jsonDecode(req.body) as Map<String, dynamic>;
          }
          final responseJson = jsonEncode({
            'id': testUserId,
            'name': 'Updated Name',
            'age': 29,
            'gender': 'male',
            'weight_kg': 72.5,
            'height_cm': 178.0,
            'goal': 'gain',
            'fitness_level': 'intermediate',
            'onboarding_completed': true,
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(responseJson)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
            contentLength: utf8.encode(responseJson).length,
            request: req,
          );
        }),
      );

      final repo = SupabaseProfileRepository(
        client: client,
        prefs: prefs,
        currentUserIdOverride: testUserId,
      );

      const profile = Profile(
        id: testUserId,
        name: 'Updated Name',
        age: 29,
        gender: 'male',
        weightKg: 72.5,
        heightCm: 178.0,
        goal: 'gain',
        fitnessLevel: 'intermediate',
        onboardingCompleted: true,
      );

      final saved = await repo.upsertProfile(profile);

      // Verify request method and URL query
      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'PATCH');
      expect(capturedRequest!.url.toString(), contains('id=eq.$testUserId'));

      // Verify protected / immutable columns were NOT sent
      expect(capturedPayload, isNotNull);
      expect(capturedPayload!.containsKey('id'), isFalse,
          reason: 'id must be excluded from UPDATE payload');
      expect(capturedPayload!.containsKey('invite_token'), isFalse,
          reason: 'invite_token must be excluded from UPDATE payload');
      expect(capturedPayload!.containsKey('created_at'), isFalse,
          reason: 'created_at must be excluded from UPDATE payload');

      // Verify expected fields were sent
      expect(capturedPayload!['name'], 'Updated Name');
      expect(capturedPayload!['age'], 29);
      expect(capturedPayload!['gender'], 'male');
      expect(capturedPayload!['weight_kg'], 72.5);
      expect(capturedPayload!['height_cm'], 178.0);
      expect(capturedPayload!['goal'], 'gain');
      expect(capturedPayload!['fitness_level'], 'intermediate');

      // Verify return value
      expect(saved.id, testUserId);
      expect(saved.name, 'Updated Name');
      expect(saved.age, 29);

      // Verify local cache was updated with confirmed values
      final cachedJson = prefs.getString('cached_profile_$testUserId');
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('Updated Name'));
    });

    test('2. Unauthorized user attempting to update another profile throws ProfileUpdateException', () async {
      bool networkCalled = false;
      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          networkCalled = true;
          return http.StreamedResponse(Stream.empty(), 500, request: req);
        }),
      );

      final repo = SupabaseProfileRepository(
        client: client,
        prefs: prefs,
        currentUserIdOverride: testUserId,
      );

      const otherProfile = Profile(
        id: 'victim-user-456',
        name: 'Hacked Name',
      );

      await expectLater(
        () => repo.upsertProfile(otherProfile),
        throwsA(
          isA<ProfileUpdateException>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
      expect(networkCalled, isFalse,
          reason: 'Unauthorized updates must be rejected before calling Supabase');
    });

    test('3. Missing profile row throws ProfileUpdateException', () async {
      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          final errorBody = jsonEncode({
            'code': 'PGRST116',
            'message': 'JSON object requested, multiple (or no) rows returned',
            'details': 'The result contains 0 rows',
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(errorBody)),
            406,
            headers: {'content-type': 'application/json; charset=utf-8'},
            contentLength: utf8.encode(errorBody).length,
            request: req,
          );
        }),
      );

      final repo = SupabaseProfileRepository(
        client: client,
        prefs: prefs,
        currentUserIdOverride: testUserId,
      );

      const profile = Profile(id: testUserId, name: 'Ghost User');

      await expectLater(
        () => repo.upsertProfile(profile),
        throwsA(
          isA<ProfileUpdateException>().having(
            (e) => e.message,
            'message',
            contains('Profile row not found'),
          ),
        ),
      );
    });

    test('4a. Supabase RLS error throws ProfileUpdateException with permission denied message', () async {
      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          final errorBody = jsonEncode({
            'code': '42501',
            'message': 'new row violates row-level security policy for table "profiles"',
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(errorBody)),
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
            contentLength: utf8.encode(errorBody).length,
            request: req,
          );
        }),
      );

      final repo = SupabaseProfileRepository(
        client: client,
        prefs: prefs,
        currentUserIdOverride: testUserId,
      );

      const profile = Profile(id: testUserId, name: 'RLS Test');

      await expectLater(
        () => repo.upsertProfile(profile),
        throwsA(
          isA<ProfileUpdateException>().having(
            (e) => e.message,
            'message',
            contains('Permission denied'),
          ),
        ),
      );
    });

    test('4b. Network error saves locally to cache and throws ProfileUpdateException with isLocalOnly', () async {
      final client = SupabaseClient(
        'https://dummy.supabase.co',
        'fake-anon-key',
        httpClient: TestHttpClient((req) async {
          throw http.ClientException('Failed to connect to host');
        }),
      );

      final repo = SupabaseProfileRepository(
        client: client,
        prefs: prefs,
        currentUserIdOverride: testUserId,
      );

      const profile = Profile(
        id: testUserId,
        name: 'Offline Draft Name',
        age: 30,
        gender: 'female',
        weightKg: 60.0,
        heightCm: 165.0,
        goal: 'maintain',
        fitnessLevel: 'beginner',
      );

      await expectLater(
        () => repo.upsertProfile(profile),
        throwsA(
          isA<ProfileUpdateException>().having(
            (e) => e.isLocalOnly,
            'isLocalOnly',
            isTrue,
          ),
        ),
      );

      // Verify draft was saved to local cache for offline recovery
      final cachedJson = prefs.getString('cached_profile_$testUserId');
      expect(cachedJson, isNotNull);
      expect(cachedJson, contains('Offline Draft Name'));
    });
  });

  group('5. No false success notification after failure', () {
    test('CurrentProfileNotifier.save rethrows when repository fails', () async {
      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            _FailingProfileRepository(
              const ProfileUpdateException('Permission denied updating profile.'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      const profile = Profile(id: testUserId, name: 'Failure Test');

      await expectLater(
        () => container.read(currentProfileProvider.notifier).save(profile),
        throwsA(isA<ProfileUpdateException>()),
      );
    });

    testWidgets('EditProfileForm displays failure toast and does NOT show "Profile saved"', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          profileRepositoryProvider.overrideWithValue(
            _FailingProfileRepository(
              const ProfileUpdateException('Database connection failed'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      const existingProfile = Profile(
        id: testUserId,
        name: 'Existing Name',
        age: 25,
        gender: 'other',
        weightKg: 65.0,
        heightCm: 170.0,
        goal: 'maintain',
        fitnessLevel: 'beginner',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: EditProfileForm(profile: existingProfile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and scroll to the Save button
      final saveButton = find.widgetWithText(FilledButton, 'Save changes');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify that 'Profile saved' is NOT shown
      expect(find.text('Profile saved'), findsNothing,
          reason: 'False success notification must never appear on database failure');

      // Verify error message is displayed
      expect(find.text('Database connection failed'), findsOneWidget);
    });
  });
}

class _FailingProfileRepository implements ProfileRepository {
  _FailingProfileRepository(this.error);
  final Exception error;

  @override
  Future<Profile?> fetchProfile(String userId) async => null;

  @override
  Future<Profile> upsertProfile(Profile profile) async {
    throw error;
  }
}
