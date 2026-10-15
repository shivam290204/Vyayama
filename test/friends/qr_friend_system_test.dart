import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/auth/auth_validators.dart';
import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:fitbuddy/features/friends/data/mock_friend_repository.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/screens/user_profile_screen.dart';
import 'package:fitbuddy/features/friends/widgets/my_qr_card.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';
import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';
import 'package:fitbuddy/features/snap_streaks/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Username Validation and Generation', () {
    test('AuthValidators.username validates handles correctly', () {
      expect(AuthValidators.username('alex_fit'), isNull);
      expect(AuthValidators.username('shivam29'), isNull);
      expect(AuthValidators.username('a_b'), isNull);
      expect(AuthValidators.username('@alex_fit'), isNull);

      // Too short
      expect(AuthValidators.username('ab'), isNotNull);
      // Too long (>20)
      expect(AuthValidators.username('abcdefghijklmnopqrstuvw'), isNotNull);
      // Invalid characters
      expect(AuthValidators.username('alex fit'), isNotNull);
      expect(AuthValidators.username('alex-fit'), isNotNull);
      expect(AuthValidators.username('alex!'), isNotNull);

      // Optional by default
      expect(AuthValidators.username(''), isNull);
      expect(AuthValidators.username(null), isNull);
      expect(AuthValidators.username('', required: true), isNotNull);
    });

    test('ProfileValidators.username validates handles correctly', () {
      expect(ProfileValidators.username('fitness_pro'), isNull);
      expect(ProfileValidators.username('@fitness_pro'), isNull);
      expect(ProfileValidators.username('ab'), isNotNull);
      expect(ProfileValidators.username('user with space'), isNotNull);
      expect(ProfileValidators.username(''), isNull);
      expect(ProfileValidators.username('', required: true), isNotNull);
    });

    test('ProfileValidators.generateDefaultUsername derives clean handles', () {
      final handle1 = ProfileValidators.generateDefaultUsername('Shivam Tiwari', null);
      expect(handle1, startsWith('shivam_tiwari_'));

      final handle2 = ProfileValidators.generateDefaultUsername(null, 'test.user@example.com');
      expect(handle2, startsWith('test_user_'));

      final handle3 = ProfileValidators.generateDefaultUsername('', '');
      expect(handle3, startsWith('user_'));
    });
  });

  group('Deep Links and QR Code Identifiers', () {
    test('buildProfileLink generates canonical https://vyayama.app/u/ URLs', () {
      expect(buildProfileLink('shivam_29'), 'https://vyayama.app/u/shivam_29');
      expect(buildProfileLink('@shivam_29'), 'https://vyayama.app/u/shivam_29');
      expect(
        buildProfileLink('550e8400-e29b-41d4-a716-446655440000'),
        'https://vyayama.app/u/550e8400-e29b-41d4-a716-446655440000',
      );
    });

    test('parseProfileIdentifier handles multiple URL and handle formats', () {
      expect(
        parseProfileIdentifier('https://vyayama.app/u/shivam_29'),
        'shivam_29',
      );
      expect(
        parseProfileIdentifier('https://vyayama.app/u/550e8400-e29b-41d4-a716-446655440000?ref=qr'),
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(parseProfileIdentifier('vyayama://u/alex'), 'alex');
      expect(parseProfileIdentifier('/u/alex'), 'alex');
      expect(parseProfileIdentifier('https://fitbuddy.app/invite/priya.yoga'), 'priya.yoga');
      expect(parseProfileIdentifier('@alex_fit'), 'alex_fit');
      expect(parseProfileIdentifier('alex_fit'), 'alex_fit');
      expect(parseProfileIdentifier('   '), isNull);
      expect(parseProfileIdentifier(''), isNull);
    });
  });

  group('Repository QR & Identifier Lookup', () {
    late MockFriendRepository repo;

    setUp(() {
      repo = MockFriendRepository(currentUserId: kMockUserId);
    });

    test('findByIdentifier resolves by username and UUID', () async {
      final userByUsername = await repo.findByIdentifier('sam_runs');
      expect(userByUsername, isNotNull);
      expect(userByUsername!.id, kMockSamId);

      final userById = await repo.findByIdentifier(kMockPriyaId);
      expect(userById, isNotNull);
      expect(userById!.username, 'priya.yoga');

      final unknown = await repo.findByIdentifier('nobody_exists_xyz');
      expect(unknown, isNull);
    });

    test('isUsernameAvailable correctly checks handle availability', () async {
      expect(await repo.isUsernameAvailable('sam_runs'), isFalse);
      expect(await repo.isUsernameAvailable('completely_new_handle'), isTrue);
    });
  });

  group('MyQrCard UI', () {
    testWidgets('Renders user display name, handle, QR code, and actions',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const profile = Profile(
        id: 'u-current',
        name: 'Shivam Tiwari',
        username: 'shivam_29',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MyQrCard(profile: profile),
            ),
          ),
        ),
      );

      expect(find.text('Shivam Tiwari'), findsOneWidget);
      expect(find.text('@shivam_29'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Renders permanent QR even when username is not set',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const profile = Profile(
        id: 'user-permanent-1234',
        name: 'New Athlete',
        username: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MyQrCard(profile: profile),
            ),
          ),
        ),
      );

      expect(find.text('New Athlete'), findsOneWidget);
      expect(find.text('Permanent QR'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
    });
  });

  group('UserProfileScreen Flow', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget createTestApp(String identifier) {
      final repo = MockFriendRepository(currentUserId: kMockUserId);
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          friendRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue(kMockUserId),
        ],
        child: MaterialApp(
          home: UserProfileScreen(identifier: identifier),
        ),
      );
    }

    testWidgets('Renders public profile and Add Friend button for unconnected user',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp('maya_fit'));
      await tester.pumpAndSettle();

      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('@maya_fit'), findsOneWidget);
      expect(find.text('Add Friend'), findsOneWidget);

      // Tap Add Friend
      await tester.tap(find.text('Add Friend'));
      await tester.pumpAndSettle();

      expect(find.text('Friend Request Pending'), findsOneWidget);
    });

    testWidgets('Renders Friends badge and action buttons for existing friends',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp('sam_runs'));
      await tester.pumpAndSettle();

      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('@sam_runs'), findsOneWidget);
      expect(find.text('You and this athlete are Friends'), findsOneWidget);
      expect(find.text('Send Snap'), findsOneWidget);
      expect(find.text('View Streak'), findsOneWidget);
    });

    testWidgets('Renders personal profile state when looking up own profile',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // kMockUserId is the current user in createTestApp
      await tester.pumpWidget(createTestApp(kMockUserId));
      await tester.pumpAndSettle();

      expect(find.text('This is your personal profile'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
    });
  });
}
