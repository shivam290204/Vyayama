import 'package:flutter/foundation.dart';

/// Supported equipment options for workout customization.
enum WorkoutEquipment {
  bodyweight('none', 'Bodyweight / No equipment'),
  dumbbells('dumbbells', 'Dumbbells'),
  bands('bands', 'Resistance bands'),
  barbell('barbell', 'Barbell'),
  gym('gym', 'Full gym');

  const WorkoutEquipment(this.id, this.label);

  final String id;
  final String label;

  static WorkoutEquipment fromId(String id) {
    return WorkoutEquipment.values.firstWhere(
      (e) => e.id.toLowerCase() == id.toLowerCase(),
      orElse: () => WorkoutEquipment.bodyweight,
    );
  }
}

/// Preferred workout duration options (in minutes).
enum WorkoutDurationOption {
  ten(10, '10 minutes'),
  fifteen(15, '15 minutes'),
  twenty(20, '20 minutes'),
  thirty(30, '30 minutes'),
  fortyFive(45, '45 minutes'),
  sixtyOrMore(60, '60+ minutes');

  const WorkoutDurationOption(this.minutes, this.label);

  final int minutes;
  final String label;

  static WorkoutDurationOption fromMinutes(int minutes) {
    if (minutes <= 10) return WorkoutDurationOption.ten;
    if (minutes <= 15) return WorkoutDurationOption.fifteen;
    if (minutes <= 20) return WorkoutDurationOption.twenty;
    if (minutes <= 30) return WorkoutDurationOption.thirty;
    if (minutes <= 45) return WorkoutDurationOption.fortyFive;
    return WorkoutDurationOption.sixtyOrMore;
  }
}

/// Preferred time of day for scheduled or recommended workouts.
enum PreferredWorkoutTime {
  earlyMorning('early_morning', 'Early morning (5:00 - 8:00 AM)'),
  morning('morning', 'Morning (8:00 - 12:00 PM)'),
  afternoon('afternoon', 'Afternoon (12:00 - 5:00 PM)'),
  evening('evening', 'Evening (5:00 - 9:00 PM)'),
  flexible('flexible', 'Flexible / Any time');

  const PreferredWorkoutTime(this.id, this.label);

  final String id;
  final String label;

  static PreferredWorkoutTime fromId(String id) {
    return PreferredWorkoutTime.values.firstWhere(
      (t) => t.id.toLowerCase() == id.toLowerCase(),
      orElse: () => PreferredWorkoutTime.flexible,
    );
  }
}

/// Explicit, user-configurable fitness preferences stored locally per user.
@immutable
class UserFitnessPreferences {
  const UserFitnessPreferences({
    required this.userId,
    this.availableEquipment = const ['none', 'dumbbells'],
    this.dailyWorkoutMinutes = 30,
    this.preferredWorkoutTime = 'flexible',
    this.updatedAt,
  });

  /// Factory producing safe default preferences for new or unconfigured users.
  factory UserFitnessPreferences.defaults({required String userId}) {
    return UserFitnessPreferences(
      userId: userId,
      availableEquipment: const ['none', 'dumbbells'],
      dailyWorkoutMinutes: 30,
      preferredWorkoutTime: PreferredWorkoutTime.flexible.id,
      updatedAt: DateTime.now(),
    );
  }

  factory UserFitnessPreferences.fromJson(Map<String, dynamic> json) {
    final rawEq = json['available_equipment'];
    List<String> equipmentList;
    if (rawEq is List) {
      equipmentList = rawEq.map((e) => e.toString()).toList();
    } else {
      equipmentList = const ['none', 'dumbbells'];
    }

    return UserFitnessPreferences(
      userId: json['user_id']?.toString() ?? 'local_user',
      availableEquipment: equipmentList.isEmpty ? const ['none'] : equipmentList,
      dailyWorkoutMinutes: (json['daily_workout_minutes'] as num?)?.toInt() ?? 30,
      preferredWorkoutTime: json['preferred_workout_time']?.toString() ?? 'flexible',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  final String userId;
  final List<String> availableEquipment;
  final int dailyWorkoutMinutes;
  final String preferredWorkoutTime;
  final DateTime? updatedAt;

  PreferredWorkoutTime get preferredTimeEnum =>
      PreferredWorkoutTime.fromId(preferredWorkoutTime);

  WorkoutDurationOption get durationOption =>
      WorkoutDurationOption.fromMinutes(dailyWorkoutMinutes);

  List<WorkoutEquipment> get equipmentEnums =>
      availableEquipment.map(WorkoutEquipment.fromId).toList();

  UserFitnessPreferences copyWith({
    String? userId,
    List<String>? availableEquipment,
    int? dailyWorkoutMinutes,
    String? preferredWorkoutTime,
    DateTime? updatedAt,
  }) {
    return UserFitnessPreferences(
      userId: userId ?? this.userId,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      dailyWorkoutMinutes: dailyWorkoutMinutes ?? this.dailyWorkoutMinutes,
      preferredWorkoutTime: preferredWorkoutTime ?? this.preferredWorkoutTime,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'available_equipment': availableEquipment,
        'daily_workout_minutes': dailyWorkoutMinutes,
        'preferred_workout_time': preferredWorkoutTime,
        'updated_at': (updatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };
}

