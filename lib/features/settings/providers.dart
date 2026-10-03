import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/services/shared_prefs_provider.dart';
import 'package:fitbuddy/core/utils/time_of_day_utils.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';

const String _unitKey = 'unit_system';
const String _morningKey = 'notif_morning_time';
const String _eveningKey = 'notif_evening_time';
const String _mutedKey = 'notif_muted_categories';

/// Selected measurement system, persisted in shared_preferences.
class UnitSystemNotifier extends Notifier<UnitSystem> {
  @override
  UnitSystem build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_unitKey);
    return UnitSystem.values.firstWhere(
      (u) => u.name == saved,
      orElse: () => UnitSystem.metric,
    );
  }

  Future<void> setSystem(UnitSystem system) async {
    state = system;
    await ref.read(sharedPreferencesProvider).setString(_unitKey, system.name);
  }
}

final unitSystemProvider =
    NotifierProvider<UnitSystemNotifier, UnitSystem>(UnitSystemNotifier.new);

/// Notification categories the user can mute (spec Section 10).
enum NotificationCategory {
  morningQuote,
  eveningMeme,
  workout,
  meal,
  medicine,
  sleep,
  friends,
  streaks,
}

extension NotificationCategoryInfo on NotificationCategory {
  String get label => switch (this) {
        NotificationCategory.morningQuote => 'Morning quote',
        NotificationCategory.eveningMeme => 'Evening meme',
        NotificationCategory.workout => 'Workout reminders',
        NotificationCategory.meal => 'Meal reminders',
        NotificationCategory.medicine => 'Medicine reminders',
        NotificationCategory.sleep => 'Bedtime and wake-up',
        NotificationCategory.friends => 'Friends and snaps',
        NotificationCategory.streaks => 'Streak alerts',
      };

  String get description => switch (this) {
        NotificationCategory.morningQuote => 'A little motivation to start the day',
        NotificationCategory.eveningMeme => 'A light, funny health meme',
        NotificationCategory.workout => 'Nudges when a workout block is due',
        NotificationCategory.meal => 'Reminders at your meal times',
        NotificationCategory.medicine => 'Reminders only, never advice',
        NotificationCategory.sleep => 'Bedtime and wake-up alerts',
        NotificationCategory.friends => 'Requests, snaps and "your turn" nudges',
        NotificationCategory.streaks => 'Streak at risk and milestones',
      };
}

/// Notification preferences (UI and provider state only for now).
/// The notification scheduler (another part) should read these values.
@immutable
class NotificationPrefs {
  const NotificationPrefs({
    this.morningQuoteTime = const TimeOfDay(hour: 8, minute: 0),
    this.eveningMemeTime = const TimeOfDay(hour: 20, minute: 0),
    this.muted = const <NotificationCategory>{},
  });

  final TimeOfDay morningQuoteTime;
  final TimeOfDay eveningMemeTime;
  final Set<NotificationCategory> muted;

  bool isMuted(NotificationCategory category) => muted.contains(category);

  NotificationPrefs copyWith({
    TimeOfDay? morningQuoteTime,
    TimeOfDay? eveningMemeTime,
    Set<NotificationCategory>? muted,
  }) {
    return NotificationPrefs(
      morningQuoteTime: morningQuoteTime ?? this.morningQuoteTime,
      eveningMemeTime: eveningMemeTime ?? this.eveningMemeTime,
      muted: muted ?? this.muted,
    );
  }
}

class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final mutedNames = prefs.getStringList(_mutedKey) ?? const <String>[];
    const defaults = NotificationPrefs();
    return NotificationPrefs(
      morningQuoteTime:
          parseSqlTime(prefs.getString(_morningKey)) ?? defaults.morningQuoteTime,
      eveningMemeTime:
          parseSqlTime(prefs.getString(_eveningKey)) ?? defaults.eveningMemeTime,
      muted: NotificationCategory.values
          .where((c) => mutedNames.contains(c.name))
          .toSet(),
    );
  }

  Future<void> setMorningQuoteTime(TimeOfDay time) async {
    state = state.copyWith(morningQuoteTime: time);
    await ref.read(sharedPreferencesProvider).setString(_morningKey, formatHm(time));
  }

  Future<void> setEveningMemeTime(TimeOfDay time) async {
    state = state.copyWith(eveningMemeTime: time);
    await ref.read(sharedPreferencesProvider).setString(_eveningKey, formatHm(time));
  }

  Future<void> setMuted(NotificationCategory category, bool muted) async {
    final next = {...state.muted};
    muted ? next.add(category) : next.remove(category);
    state = state.copyWith(muted: next);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_mutedKey, next.map((c) => c.name).toList());
  }
}

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
  NotificationPrefsNotifier.new,
);
