import 'dart:typed_data';

import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/data/friend_repository.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/settings/widgets/privacy_policy_sheet.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_repository.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/screens/snap_view_screen.dart';
import 'package:fitbuddy/features/auth/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TestSnapRepository implements SnapRepository {
  final List<Map<String, String>> reportedSnaps = [];

  @override
  Future<void> reportSnap(String snapId, String reason) async {
    reportedSnaps.add({'snap_id': snapId, 'reason': reason});
  }

  @override
  Future<void> markViewed(String snapId) async {}

  @override
  Future<void> react(String snapId, String reaction) async {}

  @override
  Future<List<ReceivedSnap>> inbox() async => [];

  @override
  Future<List<ReceivedSnap>> feed() async => [];

  @override
  Future<ReceivedSnap?> getReceived(String snapId) async => null;

  @override
  Future<List<Snap>> submitSnap({
    required SnapDraft draft,
    required Uint8List imageBytes,
  }) async =>
      [];
}

class TestFriendRepository implements FriendRepository {
  final List<String> blockedUsers = [];
  final List<Map<String, String>> reportedUsers = [];

  @override
  Future<void> blockUser(String userId) async {
    blockedUsers.add(userId);
  }

  @override
  Future<void> reportUser(String userId, String reason) async {
    reportedUsers.add({'user_id': userId, 'reason': reason});
  }

  @override
  Future<void> acceptRequest(String friendshipId) async {}

  @override
  Future<void> cancelRequest(String friendshipId) async {}

  @override
  Future<void> declineRequest(String friendshipId) async {}

  @override
  Future<FriendUser?> findByIdentifier(String identifier) async => null;

  @override
  Future<FriendUser?> findByUsername(String exactUsername) async => null;

  @override
  Future<List<FriendUser>> friends() async => [];

  @override
  Future<FriendUser?> getUser(String id) async {
    if (blockedUsers.contains(id)) return null;
    return FriendUser(id: id, username: 'user', name: 'User');
  }

  @override
  Future<bool> isUsernameAvailable(String username) async => true;

  @override
  Future<FriendRelation> relationTo(String userId) async =>
      blockedUsers.contains(userId) ? FriendRelation.none : FriendRelation.friends;

  @override
  Future<void> removeFriend(String friendId) async {}

  @override
  Future<List<FriendRequest>> requests() async => [];

  @override
  Future<void> sendRequest(String addresseeId) async {}
}

void main() {
  group('UGC Reporting & Repository Tests', () {
    test('TestSnapRepository records reports with snapId and reason', () async {
      final repo = TestSnapRepository();
      expect(repo.reportedSnaps, isEmpty);

      await repo.reportSnap('snap-123', 'Inappropriate or adult content');

      expect(repo.reportedSnaps.length, 1);
      expect(repo.reportedSnaps.first['snap_id'], 'snap-123');
      expect(repo.reportedSnaps.first['reason'], 'Inappropriate or adult content');
    });
  });

  group('SnapViewScreen UGC Reporting & Blocking Widget Tests', () {
    late TestSnapRepository testSnapRepo;
    late TestFriendRepository testFriendRepo;

    final testSnap = Snap(
      id: 'snap-456',
      senderId: 'user-maya',
      imagePath: 'mock://maya.jpg',
      activityType: ActivityType.workout,
      createdAt: DateTime.utc(2026, 10, 25, 10, 0),
      expiresAt: DateTime.utc(2026, 10, 26, 10, 0),
      verificationStatus: VerificationStatus.verified,
    );

    final testReceivedSnap = ReceivedSnap(
      snap: testSnap,
      senderName: 'Maya',
    );

    setUp(() {
      testSnapRepo = TestSnapRepository();
      testFriendRepo = TestFriendRepository();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          snapRepositoryProvider.overrideWithValue(testSnapRepo),
          friendRepositoryProvider.overrideWithValue(testFriendRepo),
          receivedSnapProvider('snap-456').overrideWith(
            (ref) async => testReceivedSnap,
          ),
          signedUrlProvider('mock://maya.jpg').overrideWith(
            (ref) async => 'mock://maya.jpg',
          ),
        ],
        child: const MaterialApp(
          home: SnapViewScreen(snapId: 'snap-456'),
        ),
      );
    }

    testWidgets('shows report dialog with standard UGC reasons and blocking checkbox',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Report button in AppBar
      final reportBtn = find.byIcon(Icons.flag_outlined);
      expect(reportBtn, findsOneWidget);

      await tester.tap(reportBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Report this snap'), findsOneWidget);
      expect(find.text('Inappropriate or adult content'), findsOneWidget);
      expect(find.text('Violence or dangerous activity'), findsOneWidget);
      expect(find.text('Bullying or harassment'), findsOneWidget);
      expect(find.text('Not exercise related'), findsOneWidget);
      expect(find.text('Spam or misleading'), findsOneWidget);
      expect(find.text('Something else'), findsOneWidget);
      expect(find.text('Also block Maya'), findsOneWidget);

      // Submit button is disabled initially
      final submitBtn = find.widgetWithText(FilledButton, 'Submit Report');
      expect(tester.widget<FilledButton>(submitBtn).enabled, isFalse);

      // Cancel dismisses dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Report this snap'), findsNothing);
      expect(testSnapRepo.reportedSnaps, isEmpty);
    });

    testWidgets('submitting report without blocking registers report only', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.text('Inappropriate or adult content'));
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(FilledButton, 'Submit Report');
      expect(tester.widget<FilledButton>(submitBtn).enabled, isTrue);

      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Report submitted
      expect(testSnapRepo.reportedSnaps.length, 1);
      expect(testSnapRepo.reportedSnaps.first['snap_id'], 'snap-456');
      expect(testSnapRepo.reportedSnaps.first['reason'], 'Inappropriate or adult content');

      // User was not blocked
      expect(testFriendRepo.blockedUsers, isEmpty);
      expect(find.text('Thanks for letting us know. Our moderation team will review this photo.'),
          findsOneWidget);
    });

    testWidgets('submitting report with block checkbox blocks sender', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      // Select reason
      await tester.tap(find.text('Bullying or harassment'));
      await tester.pumpAndSettle();

      // Check also block Maya
      final blockFinder = find.text('Also block Maya');
      await tester.ensureVisible(blockFinder);
      await tester.tap(blockFinder);
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(FilledButton, 'Submit Report');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Report submitted
      expect(testSnapRepo.reportedSnaps.length, 1);
      expect(testSnapRepo.reportedSnaps.first['reason'], 'Bullying or harassment');

      // Maya is now blocked
      expect(testFriendRepo.blockedUsers, contains('user-maya'));
      expect(find.text('Report submitted. Maya has been blocked.'), findsOneWidget);
    });
  });

  group('SignupScreen Community Standards & EULA Agreement', () {
    testWidgets('displays agreement to Community Standards & opens PrivacyPolicySheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SignupScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check text mentions Community Standards and objectionable or unsafe content
      expect(find.textContaining('Terms, Community Standards & Privacy Policy'), findsOneWidget);
      expect(
        find.textContaining('photos must not contain objectionable or unsafe content'),
        findsOneWidget,
      );

      // Tap on the linked text to open the PrivacyPolicySheet
      await tester.tap(find.text('Terms, Community Standards & Privacy Policy'));
      await tester.pumpAndSettle();

      // Bottom sheet is presented
      expect(find.byType(PrivacyPolicySheet), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('1. What We Collect'), findsOneWidget);

      final communitySectionFinder = find.text('4. Community Standards & Moderation');
      await tester.scrollUntilVisible(
        communitySectionFinder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(communitySectionFinder, findsOneWidget);
    });
  });
}
