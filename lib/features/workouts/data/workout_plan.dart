import 'package:flutter/foundation.dart';

/// One exercise inside a plan day (table `plan_exercises`).
@immutable
class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.exerciseId,
    this.sortOrder = 0,
    this.sets,
    this.reps,
    this.durationSec,
    this.restSec = 45,
  });

  /// [dayId] and [index] are used to build an id when the JSON has none.
  factory PlanExercise.fromJson(
    Map<String, dynamic> json, {
    String? dayId,
    int index = 0,
  }) {
    return PlanExercise(
      id: json['id']?.toString() ?? '${dayId ?? 'day'}_ex$index',
      exerciseId: json['exercise_id'].toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? index,
      sets: (json['sets'] as num?)?.toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      durationSec: (json['duration_sec'] as num?)?.toInt(),
      restSec: (json['rest_sec'] as num?)?.toInt() ?? 45,
    );
  }

  final String id;
  final String exerciseId;
  final int sortOrder;
  final int? sets;
  final int? reps;
  final int? durationSec;
  final int restSec;

  /// True when this exercise is done against a timer instead of reps.
  bool get isTimed => (durationSec ?? 0) > 0;

  /// Number of sets, never below 1.
  int get setCount => (sets == null || sets! < 1) ? 1 : sets!;

  PlanExercise copyWith({
    String? exerciseId,
    int? sortOrder,
    int? sets,
    int? reps,
    int? durationSec,
    int? restSec,
    bool clearReps = false,
    bool clearDuration = false,
  }) {
    return PlanExercise(
      id: id,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      sets: sets ?? this.sets,
      reps: clearReps ? null : (reps ?? this.reps),
      durationSec: clearDuration ? null : (durationSec ?? this.durationSec),
      restSec: restSec ?? this.restSec,
    );
  }

  Map<String, dynamic> toJson(String planDayId) => {
        'id': id,
        'plan_day_id': planDayId,
        'exercise_id': exerciseId,
        'sort_order': sortOrder,
        'sets': sets,
        'reps': reps,
        'duration_sec': durationSec,
        'rest_sec': restSec,
      };
}

/// One day of a plan (table `plan_days`). [dayNumber] is the weekday,
/// 1 = Monday ... 7 = Sunday.
@immutable
class PlanDay {
  const PlanDay({
    required this.id,
    required this.dayNumber,
    required this.name,
    required this.exercises,
  });

  factory PlanDay.fromJson(Map<String, dynamic> json, {String? planId}) {
    final dayNumber = (json['day_number'] as num).toInt();
    final id = json['id']?.toString() ?? '${planId ?? 'plan'}_d$dayNumber';
    final raw = (json['exercises'] as List?) ?? const [];
    final exercises = <PlanExercise>[
      for (var i = 0; i < raw.length; i++)
        PlanExercise.fromJson(
          raw[i] as Map<String, dynamic>,
          dayId: id,
          index: i,
        ),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return PlanDay(
      id: id,
      dayNumber: dayNumber,
      name: (json['name'] as String?) ?? 'Day $dayNumber',
      exercises: exercises,
    );
  }

  final String id;
  final int dayNumber;
  final String name;
  final List<PlanExercise> exercises;

  PlanDay copyWith({
    int? dayNumber,
    String? name,
    List<PlanExercise>? exercises,
  }) {
    return PlanDay(
      id: id,
      dayNumber: dayNumber ?? this.dayNumber,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }

  Map<String, dynamic> toJson(String planId) => {
        'id': id,
        'plan_id': planId,
        'day_number': dayNumber,
        'name': name,
        'exercises': [for (final e in exercises) e.toJson(id)],
      };
}

/// A workout plan (table `workout_plans`) with its days nested.
@immutable
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.days,
    this.goal,
    this.level,
    this.isSystem = false,
    this.ownerId,
  });

  /// A blank custom plan for the builder.
  factory WorkoutPlan.draft() => WorkoutPlan(
        id: 'draft_${DateTime.now().microsecondsSinceEpoch}',
        title: '',
        goal: 'maintain',
        level: 'beginner',
        days: const [],
      );

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    final id = json['id'].toString();
    final days = <PlanDay>[
      for (final d in (json['days'] as List?) ?? const [])
        PlanDay.fromJson(d as Map<String, dynamic>, planId: id),
    ]..sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
    return WorkoutPlan(
      id: id,
      title: (json['title'] as String?) ?? '',
      goal: json['goal'] as String?,
      level: json['level'] as String?,
      isSystem: (json['is_system'] as bool?) ?? false,
      ownerId: json['owner_id']?.toString(),
      days: days,
    );
  }

  final String id;
  final String title;
  final String? goal;
  final String? level;
  final bool isSystem;
  final String? ownerId;
  final List<PlanDay> days;

  int get totalExercises =>
      days.fold<int>(0, (sum, d) => sum + d.exercises.length);

  /// The day scheduled on [weekday] (1 = Monday), or null on rest days.
  PlanDay? dayForWeekday(int weekday) {
    for (final d in days) {
      if (d.dayNumber == weekday) return d;
    }
    return null;
  }

  WorkoutPlan copyWith({
    String? id,
    String? title,
    String? goal,
    String? level,
    bool? isSystem,
    String? ownerId,
    List<PlanDay>? days,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      isSystem: isSystem ?? this.isSystem,
      ownerId: ownerId ?? this.ownerId,
      days: days ?? this.days,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'goal': goal,
        'level': level,
        'is_system': isSystem,
        'owner_id': ownerId,
        'days': [for (final d in days) d.toJson(id)],
      };
}
