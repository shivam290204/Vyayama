import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/invite_link.dart';
import 'package:fitbuddy/features/friends/data/mock_friend_repository.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/screens/add_friend_screen.dart';
import 'package:fitbuddy/features/friends/screens/friend_detail_screen.dart';
import 'package:fitbuddy/features/friends/screens/friend_requests_screen.dart';
import 'package:fitbuddy/features/friends/screens/friends_list_screen.dart';
import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Friend models & invite links', () {
    test('FriendUser model initials and JSON serialization', () {
      const user = FriendUser(
        id: 'u-1',
        username: 'runner_john',
        name: 'John Doe',
        avatarUrl: 'https://example.com/avatar.jpg',
        timezone: 'UTC',
      );

      expect(user.initials, 'JD');
      expect(const FriendUser(id: 'u-2', username: 'bob', name: 'Bob').initials, 'B');
      expect(const FriendUser(id: 'u-3', username: '', name: '   ').initials, '?');

      final json = user.toJson();
      expect(json['id'], 'u-1');
      expect(json['username'], 'runner_john');
      expect(json['name'], 'John Doe');

      final fromJson = FriendUser.fromJson(json);
      expect(fromJson.id, user.id);
      expect(fromJson.username, user.username);
      expect(fromJson.name, user.name);
      expect(fromJson.avatarUrl, user.avatarUrl);
      expect(fromJson.timezone, user.timezone);
    });

    test('Friendship JSON serialization and status mapping', () {
      final now = DateTime.now();
      final friendship = Friendship(
        id: 'fs-1',
        requesterId: 'u-1',
        addresseeId: 'u-2',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );

      final json = friendship.toJson();
      expect(json['id'], 'fs-1');
      expect(json['status'], 'accepted');

      final fromJson = Friendship.fromJson(json);
      expect(fromJson.id, 'fs-1');
      expect(fromJson.status, FriendshipStatus.accepted);
    });

    test('Invite link generator and parser', () {
      final link = buildInviteLink('priya.yoga');
      expect(link, 'https://fitbuddy.app/invite/priya.yoga');

      expect(parseInviteUsername('https://fitbuddy.app/invite/priya.yoga'), 'priya.yoga');
      expect(parseInviteUsername('https://fitbuddy.app/invite/priya.yoga?ref=qr'), 'priya.yoga');
      expect(parseInviteUsername('https://fitbuddy.app/invite/priya.yoga#section'), 'priya.yoga');
      expect(parseInviteUsername('@priya.yoga'), 'priya.yoga');
      expect(parseInviteUsername('priya.yoga'), 'priya.yoga');
      expect(parseInviteUsername('   @priya.yoga   '), 'priya.yoga');
      expect(parseInviteUsername(''), isNull);
      expect(parseInviteUsername('   '), isNull);
    });
  });

  group('MockFriendRepository operations', () {
    late MockFriendRepository repo;

    setUp(() {
      repo = MockFriendRepository(currentUserId: kMockUserId);
    });

    test('friends() returns initial seeded friends', () async {
      final friends = await repo.friends();
      expect(friends.length, 3);
      final ids = friends.map((f) => f.id).toSet();
      expect(ids, containsAll([kMockSamId, kMockPriyaId, kMockArjunId]));
    });

    test('getUser() returns friend if connected, null otherwise', () async {
      final friend = await repo.getUser(kMockSamId);
      expect(friend, isNotNull);
      expect(friend!.username, 'sam_runs');

      final notFriend = await repo.getUser(kMockMayaId);
      expect(notFriend, isNull);
    });

    test('findByUsername() exact matching is case-insensitive', () async {
      final sam = await repo.findByUsername('SAM_RUNS');
      expect(sam, isNotNull);
      expect(sam!.id, kMockSamId);

      final unknown = await repo.findByUsername('non_existent_user');
      expect(unknown, isNull);

      final empty = await repo.findByUsername('');
      expect(empty, isNull);
    });

    test('relationTo() identifies friends, incoming, outgoing, and unconnected', () async {
      expect(await repo.relationTo(kMockSamId), FriendRelation.friends);
      expect(await repo.relationTo(kMockNehaId), FriendRelation.requestReceived);
      expect(await repo.relationTo(kMockRohanId), FriendRelation.requestSent);
      expect(await repo.relationTo(kMockMayaId), FriendRelation.none);
    });

    test('sendRequest() adds an outgoing request and prevents duplicates/self', () async {
      await repo.sendRequest(kMockMayaId);
      expect(await repo.relationTo(kMockMayaId), FriendRelation.requestSent);

      // Duplicate throws StateError
      expect(() => repo.sendRequest(kMockMayaId), throwsStateError);
      // Self-request throws StateError
      expect(() => repo.sendRequest(kMockUserId), throwsStateError);
    });

    test('acceptRequest() moves user to friends list', () async {
      final requestsBefore = await repo.requests();
      final nehaRequest = requestsBefore.firstWhere((r) => r.user.id == kMockNehaId);

      await repo.acceptRequest(nehaRequest.friendship.id);

      final friendsAfter = await repo.friends();
      expect(friendsAfter.any((f) => f.id == kMockNehaId), isTrue);

      final requestsAfter = await repo.requests();
      expect(requestsAfter.any((r) => r.user.id == kMockNehaId), isFalse);
    });

    test('declineRequest() removes incoming request without adding friend', () async {
      final requestsBefore = await repo.requests();
      final nehaRequest = requestsBefore.firstWhere((r) => r.user.id == kMockNehaId);

      await repo.declineRequest(nehaRequest.friendship.id);

      final friendsAfter = await repo.friends();
      expect(friendsAfter.any((f) => f.id == kMockNehaId), isFalse);

      final requestsAfter = await repo.requests();
      expect(requestsAfter.any((r) => r.user.id == kMockNehaId), isFalse);
    });

    test('cancelRequest() removes outgoing request', () async {
      final requestsBefore = await repo.requests();
      final rohanRequest = requestsBefore.firstWhere((r) => r.user.id == kMockRohanId);

      await repo.cancelRequest(rohanRequest.friendship.id);

      final requestsAfter = await repo.requests();
      expect(requestsAfter.any((r) => r.user.id == kMockRohanId), isFalse);
    });

    test('removeFriend() removes user from friends', () async {
      await repo.removeFriend(kMockSamId);
      final friends = await repo.friends();
      expect(friends.any((f) => f.id == kMockSamId), isFalse);
      expect(await repo.relationTo(kMockSamId), FriendRelation.none);
    });

    test('blockUser() removes user from friends/requests and hides from search', () async {
      await repo.blockUser(kMockPriyaId);
      final friends = await repo.friends();
      expect(friends.any((f) => f.id == kMockPriyaId), isFalse);

      final search = await repo.findByUsername('priya.yoga');
      expect(search, isNull);
    });
  });

  group('Friends Riverpod Providers', () {
    test('Provider graph resolves correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final friends = await container.read(friendsProvider.future);
      expect(friends.length, 3);

      final requests = await container.read(friendRequestsProvider.future);
      expect(requests.length, 2);

      final badgeCount = container.read(incomingRequestCountProvider);
      expect(badgeCount, 1); // Only Neha is incoming

      final friendsWithStreak = await container.read(friendsWithStreakProvider.future);
      expect(friendsWithStreak.length, 3);

      final samDetail = await container.read(friendDetailProvider(kMockSamId).future);
      expect(samDetail, isNotNull);
      expect(samDetail!.user.id, kMockSamId);

      final nonFriend = await container.read(friendDetailProvider('unknown-id').future);
      expect(nonFriend, isNull);
    });
  });

  group('Friends UI Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('FriendsListScreen renders seeded friends and buttons', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: FriendsListScreen(),
          ),
        ),
      );

      await tester.pump();
      // Allow async future providers to load
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check title and friends
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('Priya Nair'), findsOneWidget);
      expect(find.text('Arjun'), findsOneWidget);

      // Check Add Friend button exists in AppBar
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddFriendScreen allows searching by username and handles results', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: AddFriendScreen(),
          ),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Add a friend'), findsOneWidget);
      expect(find.text('Find by username'), findsOneWidget);
      expect(find.text('Scan a QR code'), findsOneWidget);

      // Search for maya_fit with leading @
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, '@maya_fit');
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify Maya is found with an Add button
      expect(find.text('Maya'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add'), findsOneWidget);

      // Tap Add button
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Shows 'Request sent'
      expect(find.text('Request sent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FriendRequestsScreen displays incoming and outgoing requests', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: FriendRequestsScreen(),
          ),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Friend requests'), findsOneWidget);
      expect(find.text('Wants to be your friend'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);

      expect(find.text('Waiting for a reply'), findsOneWidget);
      expect(find.text('Rohan'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Accept for Neha
      await tester.tap(find.text('Accept'));
      await tester.pump();
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('FriendDetailScreen renders friend profile and options', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: FriendDetailScreen(friendId: kMockSamId),
          ),
        ),
      );

      await tester.pump();
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Sam'), findsWidgets);
      expect(find.text('@sam_runs'), findsOneWidget);
      expect(find.text('Streak history'), findsOneWidget);
      expect(find.text('Send Sam a snap'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
