import 'package:flutter/foundation.dart';

/// Which side of a pair a user is on (`user_a` or `user_b`).
enum StreakSide { a, b }

extension StreakSideX on StreakSide {
  StreakSide get other => this == StreakSide.a ? StreakSide.b : StreakSide.a;
}

/// Returns the two ids ordered so that the first is smaller (`user_a < user_b`).
(String, String) orderedPair(String x, String y) =>
    x.compareTo(y) < 0 ? (x, y) : (y, x);

DateTime? _parseDate(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  final p = DateTime.parse(s.length >= 10 ? s.substring(0, 10) : s);
  return DateTime.utc(p.year, p.month, p.day);
}

String? _formatDate(DateTime? d) {
  if (d == null) return null;
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$m-$day';
}

/// One row of `snap_streaks`: the streak shared by exactly two friends.
///
/// All dates are date-only values stored as UTC midnight and represent the
/// calendar day in [timezone].
@immutable
class SnapStreak {
  const SnapStreak({
    required this.id,
    required this.userA,
    required this.userB,
    this.current = 0,
    this.longest = 0,
    this.lastASnapDate,
    this.lastBSnapDate,
    this.lastCompletedDate,
    this.timezone = 'UTC',
    this.createdAt,
  });

  factory SnapStreak.fromJson(Map<String, dynamic> j) => SnapStreak(
        id: j['id'] as String,
        userA: j['user_a'] as String,
        userB: j['user_b'] as String,
        current: (j['current'] as int?) ?? 0,
        longest: (j['longest'] as int?) ?? 0,
        lastASnapDate: _parseDate(j['last_a_snap_date']),
        lastBSnapDate: _parseDate(j['last_b_snap_date']),
        lastCompletedDate: _parseDate(j['last_completed_date']),
        timezone: (j['timezone'] as String?) ?? 'UTC',
        createdAt: j['created_at'] == null
            ? null
            : DateTime.parse(j['created_at'] as String),
      );

  final String id;
  final String userA;
  final String userB;
  final int current;
  final int longest;
  final DateTime? lastASnapDate;
  final DateTime? lastBSnapDate;
  final DateTime? lastCompletedDate;
  final String timezone;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_a': userA,
        'user_b': userB,
        'current': current,
        'longest': longest,
        'last_a_snap_date': _formatDate(lastASnapDate),
        'last_b_snap_date': _formatDate(lastBSnapDate),
        'last_completed_date': _formatDate(lastCompletedDate),
        'timezone': timezone,
        'created_at': createdAt?.toIso8601String(),
      };

  SnapStreak copyWith({
    int? current,
    int? longest,
    DateTime? lastASnapDate,
    DateTime? lastBSnapDate,
    DateTime? lastCompletedDate,
    String? timezone,
  }) =>
      SnapStreak(
        id: id,
        userA: userA,
        userB: userB,
        current: current ?? this.current,
        longest: longest ?? this.longest,
        lastASnapDate: lastASnapDate ?? this.lastASnapDate,
        lastBSnapDate: lastBSnapDate ?? this.lastBSnapDate,
        lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
        timezone: timezone ?? this.timezone,
        createdAt: createdAt,
      );

  /// The side [userId] is on, or null when the user is not part of this pair.
  StreakSide? sideOf(String userId) {
    if (userId == userA) return StreakSide.a;
    if (userId == userB) return StreakSide.b;
    return null;
  }

  /// The id of the other person in the pair.
  String partnerOf(String userId) => userId == userA ? userB : userA;

  /// Last day [side] sent a verified snap to the other person.
  DateTime? lastSnapOf(StreakSide side) =>
      side == StreakSide.a ? lastASnapDate : lastBSnapDate;
}
