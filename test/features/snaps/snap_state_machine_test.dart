import 'dart:typed_data';

import 'package:fitbuddy/features/snap_streaks/data/mock_ids.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_calculator.dart';
import 'package:fitbuddy/features/snap_streaks/data/snap_streak_repository.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/mock_snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(SnapStreakCalculator.ensureTimezones);

  group('VerificationStatus Enum & Snap Model', () {
    test('supports all 6 state machine states', () {
      const states = [
        VerificationStatus.pending,
        VerificationStatus.retrying,
        VerificationStatus.verified,
        VerificationStatus.rejected,
        VerificationStatus.appealed,
        VerificationStatus.expired,
      ];
      expect(states.length, 6);
    });

    test('serializes and deserializes all 6 statuses correctly', () {
      final now = DateTime.utc(2026, 10, 25, 10, 0);
      final rawStatusNames = ['pending', 'retrying', 'verified', 'rejected', 'appealed', 'expired'];

      for (final name in rawStatusNames) {
        final snap = Snap.fromJson({
          'id': 'snap-$name',
          'sender_id': 'user-1',
          'image_path': 'user-1/snap.jpg',
          'activity_type': 'running',
          'caption': 'Test $name',
          'is_story': false,
          'verification_status': name,
          'verification_label': 'running',
          'verification_confidence': 0.95,
          'rejection_reason': name == 'rejected' ? 'Not exercise' : null,
          'created_at': now.toIso8601String(),
          'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
        });

        expect(snap.verificationStatus.name, name);
        expect(snap.toJson()['verification_status'], name);
      }
    });

    test('defaults unknown status to pending safely', () {
      final now = DateTime.utc(2026, 10, 25, 10, 0);
      final snap = Snap.fromJson({
        'id': 'snap-unknown',
        'sender_id': 'user-1',
        'image_path': 'user-1/snap.jpg',
        'activity_type': 'running',
        'verification_status': 'some_future_status',
        'created_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(hours: 24)).toIso8601String(),
      });

      expect(snap.verificationStatus, VerificationStatus.pending);
    });

    test('isDelivered is strictly true for verified and appealed, false for others', () {
      final now = DateTime.utc(2026, 10, 25, 10, 0);
      Snap makeSnap(VerificationStatus status) => Snap(
            id: 'snap-test',
            senderId: 'user-1',
            imagePath: 'user-1/snap.jpg',
            activityType: ActivityType.running,
            verificationStatus: status,
            createdAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
          );

      expect(makeSnap(VerificationStatus.verified).isDelivered, isTrue);
      expect(makeSnap(VerificationStatus.appealed).isDelivered, isTrue);

      expect(makeSnap(VerificationStatus.pending).isDelivered, isFalse);
      expect(makeSnap(VerificationStatus.retrying).isDelivered, isFalse);
      expect(makeSnap(VerificationStatus.rejected).isDelivered, isFalse);
      expect(makeSnap(VerificationStatus.expired).isDelivered, isFalse);
    });
  });

  group('VerificationResult State Constructors and Properties', () {
    test('verified state properties', () {
      final res = VerificationResult.verified(activity: 'cycling', confidence: 0.91);
      expect(res.status, VerificationStatus.verified);
      expect(res.isVerified, isTrue);
      expect(res.isDelivered, isTrue);
      expect(res.isPending, isFalse);
      expect(res.isRetrying, isFalse);
      expect(res.isRejected, isFalse);
      expect(res.isAppealed, isFalse);
      expect(res.isExpired, isFalse);
      expect(res.activity, 'cycling');
      expect(res.confidence, 0.91);
    });

    test('rejected state properties', () {
      final res = VerificationResult.rejected(reason: 'Photo does not appear to show exercise.');
      expect(res.status, VerificationStatus.rejected);
      expect(res.isRejected, isTrue);
      expect(res.isDelivered, isFalse);
      expect(res.reason, contains('Photo does not appear'));
    });

    test('retrying state properties', () {
      final res = VerificationResult.retrying(reason: 'Service rate limit reached, queued for retry.');
      expect(res.status, VerificationStatus.retrying);
      expect(res.isRetrying, isTrue);
      expect(res.isDelivered, isFalse);
      expect(res.reason, contains('rate limit'));
    });

    test('appealed state properties', () {
      final res = VerificationResult.appealed(activity: 'yoga');
      expect(res.status, VerificationStatus.appealed);
      expect(res.isAppealed, isTrue);
      expect(res.isDelivered, isTrue);
      expect(res.activity, 'yoga');
    });

    test('expired state properties', () {
      final res = VerificationResult.expired(reason: 'Verification timeout after 24 hours.');
      expect(res.status, VerificationStatus.expired);
      expect(res.isExpired, isTrue);
      expect(res.isDelivered, isFalse);
      expect(res.reason, contains('timeout'));
    });
  });

  group('Streak Isolation: Appealed Snaps Waive Exercise but Award 0 Streaks', () {
    test('verified snap advances streak', () {
      final streak = SnapStreak(id: 's1', userA: 'a', userB: 'b', timezone: 'UTC');
      final day1 = DateTime.utc(2026, 10, 20, 10, 0);

      final updateA = SnapStreakCalculator.applySnap(
        streak: streak,
        sender: StreakSide.a,
        nowUtc: day1,
        verified: true,
      );
      expect(updateA.event, StreakEvent.nudgeFriend);

      final updateB = SnapStreakCalculator.applySnap(
        streak: updateA.streak,
        sender: StreakSide.b,
        nowUtc: day1,
        verified: true,
      );
      expect(updateB.event, StreakEvent.completed);
      expect(updateB.streak.current, 1);
    });

    test('appealed or unverified snap (verified: false) is ignored for streaks', () {
      final streak = SnapStreak(id: 's1', userA: 'a', userB: 'b', timezone: 'UTC');
      final day1 = DateTime.utc(2026, 10, 20, 10, 0);

      // User A submits a snap that is appealed (verified: false for streaks)
      final updateA = SnapStreakCalculator.applySnap(
        streak: streak,
        sender: StreakSide.a,
        nowUtc: day1,
        verified: false, // Appealed photos deliver to friends but verified == false for streaks
      );
      expect(updateA.event, StreakEvent.ignored);
      expect(updateA.streak.lastASnapDate, isNull);
      expect(updateA.streak.current, 0);
    });
  });

  group('Streak 6-Hour Grace Window', () {
    test('snap captured yesterday before midnight is backdated if verified before 06:00', () {
      final streak = SnapStreak(id: 's1', userA: 'a', userB: 'b', timezone: 'UTC');
      // Yesterday 23:55 UTC
      final snapCapturedYesterday = DateTime.utc(2026, 10, 20, 23, 55);
      // Today 03:15 UTC (within 6-hour morning grace window)
      final verifiedAt0315 = DateTime.utc(2026, 10, 21, 3, 15);

      final update = SnapStreakCalculator.applySnap(
        streak: streak,
        sender: StreakSide.a,
        nowUtc: verifiedAt0315,
        snapCreatedAtUtc: snapCapturedYesterday,
        verified: true,
      );

      // Effective date is yesterday Oct 20, not today Oct 21!
      expect(update.streak.lastASnapDate, DateTime.utc(2026, 10, 20));
    });

    test('snap captured yesterday is NOT backdated if verified after 06:00', () {
      final streak = SnapStreak(id: 's1', userA: 'a', userB: 'b', timezone: 'UTC');
      // Yesterday 23:55 UTC
      final snapCapturedYesterday = DateTime.utc(2026, 10, 20, 23, 55);
      // Today 06:05 UTC (past 6-hour morning grace window)
      final verifiedAt0605 = DateTime.utc(2026, 10, 21, 6, 5);

      final update = SnapStreakCalculator.applySnap(
        streak: streak,
        sender: StreakSide.a,
        nowUtc: verifiedAt0605,
        snapCreatedAtUtc: snapCapturedYesterday,
        verified: true,
      );

      // Effective date falls back to today Oct 21 because grace window has passed
      expect(update.streak.lastASnapDate, DateTime.utc(2026, 10, 21));
    });
  });

  group('Appeal Workflow & Safety Enforcement in Mock Service', () {
    test('appeal succeeds on safe exercise-waived photo but fails on unsafe content', () async {
      DateTime clock() => DateTime.utc(2026, 10, 25, 10, 0);
      final repo = MockSnapRepository(currentUserId: kMockSamId, clock: clock);
      final streaks = MockSnapStreakRepository(currentUserId: kMockSamId, clock: clock);
      final service = MockSnapVerificationService(repo, streaks, kMockSamId);

      // 1. Submit normal snap rejected for non-exercise (contains "pizza")
      final submitted = await repo.submitSnap(
        draft: const SnapDraft(
          activity: ActivityType.running,
          recipientIds: [kMockPriyaId],
          postToFeed: false,
          caption: 'eating pizza after run',
        ),
        imageBytes: Uint8List(10),
      );
      final snapId = submitted.first.id;

      // Verify rejects it because of pizza
      final verifyRes = await service.verify(snapId);
      expect(verifyRes.isRejected, isTrue);

      // Now appeal it: since it's safe (no "unsafe" flag), exercise is waived and it passes!
      final appealRes = await service.appeal(snapId);
      expect(appealRes.isAppealed, isTrue);
      expect(appealRes.isDelivered, isTrue);

      // 2. Submit unsafe snap: appeal MUST fail
      final unsafeSubmitted = await repo.submitSnap(
        draft: const SnapDraft(
          activity: ActivityType.gym,
          recipientIds: [kMockPriyaId],
          postToFeed: false,
          caption: 'unsafe explicit violation',
        ),
        imageBytes: Uint8List(10),
      );
      final unsafeId = unsafeSubmitted.first.id;

      final unsafeAppeal = await service.appeal(unsafeId);
      expect(unsafeAppeal.isRejected, isTrue);
      expect(unsafeAppeal.reason, contains('content safety'));
    });
  });
}
