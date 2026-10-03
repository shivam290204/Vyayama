import 'package:fitbuddy/features/health_profile/data/time_codec.dart';
import 'package:flutter/material.dart';

/// Plain-value copy of the profile fields the wellness features need.
///
/// It is built from Claude 1's `Profile` model in one place, so a field type
/// difference only needs fixing in [ProfileSnapshot.fromProfile].
@immutable
class ProfileSnapshot {
  /// Creates a snapshot.
  const ProfileSnapshot({
    required this.id,
    this.name,
    this.age,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.goal,
    this.wakeTime,
    this.sleepTime,
    this.workStart,
    this.workEnd,
  });

  /// Reads the contract fields from a `Profile` (or anything shaped like it).
  factory ProfileSnapshot.fromProfile(dynamic p) {
    return ProfileSnapshot(
      id: (p.id ?? '').toString(),
      name: p.name?.toString(),
      age: (p.age as num?)?.toInt(),
      gender: _enumName(p.gender),
      weightKg: (p.weightKg as num?)?.toDouble(),
      heightCm: (p.heightCm as num?)?.toDouble(),
      goal: _enumName(p.goal),
      wakeTime: timeFromJson(p.wakeTime as Object?),
      sleepTime: timeFromJson(p.sleepTime as Object?),
      workStart: timeFromJson(p.workStart as Object?),
      workEnd: timeFromJson(p.workEnd as Object?),
    );
  }

  /// Profile id (auth user id).
  final String id;

  /// Display name.
  final String? name;

  /// Age in years.
  final int? age;

  /// `male`, `female` or `other`.
  final String? gender;

  /// Weight in kilograms.
  final double? weightKg;

  /// Height in centimetres.
  final double? heightCm;

  /// `lose`, `gain` or `maintain`.
  final String? goal;

  /// Usual wake time.
  final TimeOfDay? wakeTime;

  /// Usual bedtime.
  final TimeOfDay? sleepTime;

  /// Work start time.
  final TimeOfDay? workStart;

  /// Work end time.
  final TimeOfDay? workEnd;
}

String? _enumName(Object? value) {
  if (value == null) return null;
  return value.toString().split('.').last.toLowerCase();
}
