import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Friend Models Serialization', () {
    test('serializes and deserializes FriendUser', () {
      const user = FriendUser(
        id: 'u-1',
        username: 'sam_runs',
        name: 'Sam Wilson',
        avatarUrl: 'https://example.com/sam.png',
        timezone: 'America/New_York',
      );

      final json = user.toJson();
      expect(json['id'], 'u-1');
      expect(json['username'], 'sam_runs');
      expect(json['name'], 'Sam Wilson');
      expect(json['avatar_url'], 'https://example.com/sam.png');
      expect(json['timezone'], 'America/New_York');

      final deserialized = FriendUser.fromJson(json);
      expect(deserialized.id, user.id);
      expect(deserialized.username, user.username);
      expect(deserialized.name, user.name);
      expect(deserialized.initials, 'SW');
    });

    test('serializes and deserializes Friendship', () {
      final now = DateTime.utc(2026, 10, 11);
      final friendship = Friendship(
        id: 'f-1',
        requesterId: 'u-1',
        addresseeId: 'u-2',
        status: FriendshipStatus.accepted,
        createdAt: now,
      );

      final json = friendship.toJson();
      expect(json['id'], 'f-1');
      expect(json['requester_id'], 'u-1');
      expect(json['addressee_id'], 'u-2');
      expect(json['status'], 'accepted');

      final deserialized = Friendship.fromJson(json);
      expect(deserialized.id, friendship.id);
      expect(deserialized.status, FriendshipStatus.accepted);
    });
  });

  group('Snap Models Serialization', () {
    test('serializes and deserializes Snap', () {
      final created = DateTime.utc(2026, 10, 11, 8, 0);
      final expires = created.add(const Duration(hours: 24));
      final snap = Snap(
        id: 'snap-1',
        senderId: 'u-1',
        imagePath: 'u-1/snap-1.jpg',
        activityType: ActivityType.running,
        caption: 'Morning 5k run!',
        isStory: false,
        verificationStatus: VerificationStatus.verified,
        verificationLabel: 'running',
        verificationConfidence: 0.95,
        createdAt: created,
        expiresAt: expires,
      );

      final json = snap.toJson();
      expect(json['id'], 'snap-1');
      expect(json['sender_id'], 'u-1');
      expect(json['image_path'], 'u-1/snap-1.jpg');
      expect(json['activity_type'], 'running');
      expect(json['caption'], 'Morning 5k run!');
      expect(json['verification_status'], 'verified');

      final deserialized = Snap.fromJson(json);
      expect(deserialized.id, snap.id);
      expect(deserialized.activityType, ActivityType.running);
      expect(deserialized.verificationStatus, VerificationStatus.verified);
      expect(deserialized.verificationConfidence, 0.95);
    });

    test('VerificationResult states', () {
      final v1 = VerificationResult.verified(activity: 'gym', confidence: 0.88);
      expect(v1.isVerified, true);
      expect(v1.activity, 'gym');
      expect(v1.confidence, 0.88);

      final v2 = VerificationResult.rejected(reason: 'Not exercise');
      expect(v2.isVerified, false);
      expect(v2.reason, 'Not exercise');
    });
  });
}
