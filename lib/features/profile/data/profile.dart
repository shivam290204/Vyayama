import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;

import 'package:fitbuddy/core/utils/time_of_day_utils.dart';

/// Allowed string values for profile fields (match the DB check constraints).
abstract final class ProfileOptions {
  static const List<String> genders = ['male', 'female', 'other'];
  static const List<String> goals = ['lose', 'gain', 'maintain'];
  static const List<String> fitnessLevels = ['beginner', 'intermediate'];
}

double? _toDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Immutable user profile. JSON keys match the `profiles` table columns.
@immutable
class Profile {
  const Profile({
    required this.id,
    this.name,
    this.age,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.goal,
    this.fitnessLevel = 'beginner',
    this.wakeTime,
    this.sleepTime,
    this.workStart,
    this.workEnd,
    this.username,
    this.avatarUrl,
    this.timezone = 'UTC',
    this.onboardingCompleted = false,
  });

  final String id;
  final String? name;
  final int? age;

  /// `male`, `female` or `other`.
  final String? gender;
  final double? weightKg;
  final double? heightCm;

  /// `lose`, `gain` or `maintain`.
  final String? goal;

  /// `beginner` or `intermediate`.
  final String fitnessLevel;
  final TimeOfDay? wakeTime;
  final TimeOfDay? sleepTime;
  final TimeOfDay? workStart;
  final TimeOfDay? workEnd;
  final String? username;
  final String? avatarUrl;
  final String timezone;
  final bool onboardingCompleted;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String?,
      age: (json['age'] as num?)?.toInt(),
      gender: json['gender'] as String?,
      weightKg: _toDouble(json['weight_kg']),
      heightCm: _toDouble(json['height_cm']),
      goal: json['goal'] as String?,
      fitnessLevel: (json['fitness_level'] as String?) ?? 'beginner',
      wakeTime: parseSqlTime(json['wake_time']),
      sleepTime: parseSqlTime(json['sleep_time']),
      workStart: parseSqlTime(json['work_start']),
      workEnd: parseSqlTime(json['work_end']),
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      timezone: (json['timezone'] as String?) ?? 'UTC',
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'goal': goal,
      'fitness_level': fitnessLevel,
      'wake_time': wakeTime == null ? null : formatSqlTime(wakeTime!),
      'sleep_time': sleepTime == null ? null : formatSqlTime(sleepTime!),
      'work_start': workStart == null ? null : formatSqlTime(workStart!),
      'work_end': workEnd == null ? null : formatSqlTime(workEnd!),
      'username': username,
      'avatar_url': avatarUrl,
      'timezone': timezone,
      'onboarding_completed': onboardingCompleted,
    };
  }

  /// Returns a copy. Pass [clearSchedule] to remove all four schedule times.
  Profile copyWith({
    String? name,
    int? age,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? goal,
    String? fitnessLevel,
    TimeOfDay? wakeTime,
    TimeOfDay? sleepTime,
    TimeOfDay? workStart,
    TimeOfDay? workEnd,
    String? username,
    String? avatarUrl,
    String? timezone,
    bool? onboardingCompleted,
    bool clearSchedule = false,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      goal: goal ?? this.goal,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      wakeTime: clearSchedule ? null : (wakeTime ?? this.wakeTime),
      sleepTime: clearSchedule ? null : (sleepTime ?? this.sleepTime),
      workStart: clearSchedule ? null : (workStart ?? this.workStart),
      workEnd: clearSchedule ? null : (workEnd ?? this.workEnd),
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timezone: timezone ?? this.timezone,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  /// Name to show in the UI; never empty.
  String get displayName {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? 'Friend' : trimmed;
  }

  /// One or two letters for avatar placeholders.
  String get initials {
    final words = (name ?? '').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  /// True when the user is known to be under 18.
  bool get isMinor => age != null && age! < 18;
}
