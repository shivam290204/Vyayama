import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/health_profile/reminders/local_reminder_scheduler.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';
import 'package:fitbuddy/features/sleep/domain/day_time.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/reminders/sleep_reminder_builders.dart';
import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Part 1: Friend Requests & Models Logic', () {
    test('FriendRequest correctly distinguishes incoming vs outgoing', () {
      const friendship = Friendship(
        id: 'fs-123',
        requesterId: 'user-a',
        addresseeId: 'user-b',
        status: FriendshipStatus.pending,
      );

      const userA = FriendUser(id: 'user-a', username: 'usera', name: 'User A');
      const userB = FriendUser(id: 'user-b', username: 'userb', name: 'User B');

      // For user B, incoming is true (user A requested user B)
      final reqForB = FriendRequest(
        friendship: friendship,
        user: userA,
        incoming: true,
      );
      expect(reqForB.incoming, isTrue);
      expect(reqForB.user.name, 'User A');

      // For user A, incoming is false (waiting for user B's reply)
      final reqForA = FriendRequest(
        friendship: friendship,
        user: userB,
        incoming: false,
      );
      expect(reqForA.incoming, isFalse);
      expect(reqForA.user.name, 'User B');
    });

    test('FriendUser fallback handles missing profile data gracefully', () {
      const fallback = FriendUser(
        id: 'user-unknown',
        username: '',
        name: 'Pending Friend',
      );
      expect(fallback.id, 'user-unknown');
      expect(fallback.name, 'Pending Friend');
      expect(fallback.initials, 'PF');
    });
  });

  group('Part 2: Notification ID Stability & Determinism', () {
    test('stableNotificationId returns same ID across invocations', () {
      final id1 = stableNotificationId('sleep:wake');
      final id2 = stableNotificationId('sleep:wake');
      expect(id1, equals(id2));
      expect(id1, isNonNegative);

      final idMed1 = stableNotificationId('medicine:med-1:0');
      final idMed2 = stableNotificationId('medicine:med-1:0');
      expect(idMed1, equals(idMed2));
      expect(idMed1, isNot(equals(id1)));
    });

    test('stableNotificationId fits within Android 31-bit integer range', () {
      final keys = [
        'sleep:bedtime',
        'sleep:wake',
        'medicine:aspirin:0',
        'medicine:vitamin_c:1',
        'meal:breakfast',
        'meal:lunch',
        'meal:dinner',
      ];
      for (final k in keys) {
        final id = stableNotificationId(k);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });

  group('Part 3: Health & Sleep Alarm Weekdays & Scheduling', () {
    final mockPlan = SleepPlan(
      bedtime: DayTime(22, 30),
      wakeTime: DayTime(6, 30),
      windDownStart: DayTime(21, 45),
      sleepMinutes: 480,
    );

    test('buildBedtimeReminder configures gentle nudge and selected weekdays', () {
      final selectedDays = [1, 2, 3, 4, 5]; // Mon - Fri
      final reminder = buildBedtimeReminder(mockPlan, days: selectedDays);

      expect(reminder.id, equals(bedtimeReminderId));
      expect(reminder.kind, equals(ReminderKind.bedtime));
      expect(reminder.exact, isFalse);
      expect(reminder.alarmStyle, isFalse);
      expect(reminder.hour, equals(21));
      expect(reminder.minute, equals(45));
      expect(reminder.weekdays, equals(selectedDays));
    });

    test('buildWakeAlarm configures alarmStyle and selected weekdays', () {
      final selectedDays = [1, 2, 3, 4, 5, 6, 7]; // All week
      final reminder = buildWakeAlarm(mockPlan, days: selectedDays);

      expect(reminder.id, equals(wakeAlarmReminderId));
      expect(reminder.kind, equals(ReminderKind.wakeAlarm));
      expect(reminder.exact, isTrue);
      expect(reminder.alarmStyle, isTrue);
      expect(reminder.hour, equals(6));
      expect(reminder.minute, equals(30));
      expect(reminder.weekdays, equals(selectedDays));
    });

    test('ReminderRequest defaults to all 7 weekdays', () {
      const request = ReminderRequest(
        id: 'test:1',
        kind: ReminderKind.medicine,
        title: 'Med',
        body: 'Take med',
        hour: 8,
        minute: 0,
      );
      expect(request.weekdays.length, equals(7));
      expect(request.weekdays, equals([1, 2, 3, 4, 5, 6, 7]));
    });
  });

  group('Part 4: Notification Audio Asset & Sound Service', () {
    test('AppSounds.notification points to notification.mp3', () {
      expect(AppSounds.notification, equals('audio/notification.mp3'));
    });
  });

  group('Part 5: Snaps Unviewed Count & Message Badges Logic', () {
    test('unviewed count properly filters viewedAt null', () {
      final now = DateTime.now();
      Snap createMockSnap(String id) => Snap(
            id: id,
            senderId: 'user-$id',
            imagePath: 'snaps/$id.jpg',
            activityType: ActivityType.workout,
            createdAt: now,
            expiresAt: now.add(const Duration(hours: 24)),
          );

      final snapA = ReceivedSnap(
        snap: createMockSnap('s1'),
        senderName: 'Alice',
        viewedAt: null, // Unviewed
      );

      final snapB = ReceivedSnap(
        snap: createMockSnap('s2'),
        senderName: 'Bob',
        viewedAt: now, // Viewed
      );

      final snapC = ReceivedSnap(
        snap: createMockSnap('s3'),
        senderName: 'Charlie',
        viewedAt: null, // Unviewed
      );

      final snaps = [snapA, snapB, snapC];
      final unviewedCount = snaps.where((s) => s.isUnviewed).length;
      expect(unviewedCount, equals(2));

      // Test combined message badge (Friend requests + unviewed snaps)
      const friendRequestsCount = 3;
      final totalMessagesBadge = friendRequestsCount + unviewedCount;
      expect(totalMessagesBadge, equals(5));
    });
  });
}

