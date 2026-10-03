import 'package:fitbuddy/features/snap_streaks/data/snap_streak.dart';
import 'package:flutter/foundation.dart';

/// Row status of `friendships.status`.
enum FriendshipStatus { pending, accepted, declined, blocked }

FriendshipStatus _statusFrom(String? v) => FriendshipStatus.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FriendshipStatus.pending,
    );

/// How the signed-in user relates to another user.
enum FriendRelation { none, friends, requestSent, requestReceived }

/// Public bits of a profile that friends can see.
@immutable
class FriendUser {
  const FriendUser({
    required this.id,
    required this.username,
    required this.name,
    this.avatarUrl,
    this.timezone = 'UTC',
  });

  factory FriendUser.fromJson(Map<String, dynamic> j) => FriendUser(
        id: j['id'] as String,
        username: (j['username'] as String?) ?? '',
        name: (j['name'] as String?) ?? (j['username'] as String?) ?? 'Friend',
        avatarUrl: j['avatar_url'] as String?,
        timezone: (j['timezone'] as String?) ?? 'UTC',
      );

  final String id;
  final String username;
  final String name;
  final String? avatarUrl;
  final String timezone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'avatar_url': avatarUrl,
        'timezone': timezone,
      };

  /// One or two capital letters for avatar fallbacks.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

/// One row of `friendships`.
@immutable
class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    this.status = FriendshipStatus.pending,
    this.createdAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
        id: j['id'] as String,
        requesterId: j['requester_id'] as String,
        addresseeId: j['addressee_id'] as String,
        status: _statusFrom(j['status'] as String?),
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
      );

  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'requester_id': requesterId,
        'addressee_id': addresseeId,
        'status': status.name,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// A pending friendship plus the person on the other end.
@immutable
class FriendRequest {
  const FriendRequest({
    required this.friendship,
    required this.user,
    required this.incoming,
  });

  final Friendship friendship;
  final FriendUser user;

  /// True when someone asked the signed-in user, false when the user asked.
  final bool incoming;
}

/// A friend together with the pair streak (null when no snap was ever sent).
@immutable
class FriendWithStreak {
  const FriendWithStreak({required this.user, this.streak});

  final FriendUser user;
  final SnapStreak? streak;
}
