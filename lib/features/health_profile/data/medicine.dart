import 'package:fitbuddy/features/health_profile/data/time_codec.dart';
import 'package:flutter/material.dart';

/// A medicine reminder. By design it holds a name and times only:
/// no dosage, no advice and no interaction information.
@immutable
class Medicine {
  /// Creates a medicine reminder. Use an empty [id] for a new one.
  const Medicine({
    required this.id,
    required this.name,
    required this.reminderTimes,
    this.userId = '',
    this.isActive = true,
  });

  /// Reads a medicine from a `medicines` table row.
  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        userId: (json['user_id'] as String?) ?? '',
        name: json['name'] as String,
        reminderTimes: (json['reminder_times'] as List<dynamic>? ??
                const <dynamic>[])
            .map(timeFromJson)
            .whereType<TimeOfDay>()
            .toList(),
        isActive: (json['is_active'] as bool?) ?? true,
      );

  /// Row id (empty before first save).
  final String id;

  /// Owner id.
  final String userId;

  /// Medicine name as typed by the user.
  final String name;

  /// Daily reminder times.
  final List<TimeOfDay> reminderTimes;

  /// Whether reminders are switched on.
  final bool isActive;

  /// Writes the medicine using the exact column names.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'user_id': userId,
        'name': name,
        'reminder_times': reminderTimes.map(timeToJson).toList(),
        'is_active': isActive,
      };

  /// Returns a modified copy.
  Medicine copyWith({
    String? id,
    String? userId,
    String? name,
    List<TimeOfDay>? reminderTimes,
    bool? isActive,
  }) =>
      Medicine(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        reminderTimes: reminderTimes ?? this.reminderTimes,
        isActive: isActive ?? this.isActive,
      );
}
