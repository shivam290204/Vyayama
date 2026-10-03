import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/data/repository_providers.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/logic/default_plan_picker.dart';
import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';
import 'package:fitbuddy/features/workouts/logic/session_engine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:fitbuddy/features/workouts/data/repository_providers.dart';
export 'package:fitbuddy/features/workouts/state/session_notifier.dart';
export 'package:fitbuddy/features/workouts/state/workout_completed_notifier.dart';

/// All library exercises.
final exerciseLibraryProvider = FutureProvider<List<Exercise>>(
  (ref) => ref.watch(workoutRepositoryProvider).getExercises(),
);

/// One exercise by id (null if unknown).
final exerciseByIdProvider =
    FutureProvider.family<Exercise?, String>((ref, id) async {
  final all = await ref.watch(exerciseLibraryProvider.future);
  for (final e in all) {
    if (e.id == id) return e;
  }
  return null;
});

/// System plans (browse tab).
final systemPlansProvider = FutureProvider<List<WorkoutPlan>>(
  (ref) => ref.watch(workoutRepositoryProvider).getSystemPlans(),
);

/// The user's custom plans, with save and delete.
class MyPlansNotifier extends AsyncNotifier<List<WorkoutPlan>> {
  @override
  Future<List<WorkoutPlan>> build() =>
      ref.read(workoutRepositoryProvider).getMyPlans();

  /// Creates or updates a custom plan.
  Future<WorkoutPlan> save(WorkoutPlan plan) async {
    final repo = ref.read(workoutRepositoryProvider);
    final saved = await repo.savePlan(plan);
    state = AsyncData(await repo.getMyPlans());
    return saved;
  }

  /// Deletes a custom plan.
  Future<void> delete(String id) async {
    final repo = ref.read(workoutRepositoryProvider);
    await repo.deletePlan(id);
    state = AsyncData(await repo.getMyPlans());
  }
}

final myPlansProvider =
    AsyncNotifierProvider<MyPlansNotifier, List<WorkoutPlan>>(
  MyPlansNotifier.new,
);

/// A system or custom plan by id.
final planByIdProvider =
    FutureProvider.family<WorkoutPlan?, String>((ref, id) async {
  ref.watch(myPlansProvider); // refresh after saves and deletes
  return ref.watch(workoutRepositoryProvider).getPlan(id);
});

/// A plan adapted to the user's selected conditions (spec 9.5).
final adaptedPlanProvider =
    FutureProvider.family<AdaptationResult?, String>((ref, planId) async {
  final plan = await ref.watch(planByIdProvider(planId).future);
  if (plan == null) return null;
  final library = await ref.watch(exerciseLibraryProvider.future);
  final tags = ref.watch(selectedConditionTagsProvider);
  return adaptPlanForConditions(plan, tags, library);
});

/// Body weight for calorie estimates (falls back to 70 kg).
final weightKgProvider = FutureProvider<double>((ref) async {
  try {
    final Profile? profile = await ref.watch(currentProfileProvider.future);
    final num? w = profile?.weightKg;
    if (w != null && w > 0) return w.toDouble();
  } catch (_) {
    // Use the default below.
  }
  return 70.0;
});

/// The system plan recommended for the user's goal and level.
final defaultPlanProvider = FutureProvider<WorkoutPlan?>((ref) async {
  final plans = await ref.watch(systemPlansProvider.future);
  Profile? profile;
  try {
    profile = await ref.watch(currentProfileProvider.future);
  } catch (_) {
    profile = null;
  }
  final Object? rawAge = profile?.age;
  return pickDefaultPlan(
    plans: plans,
    goal: profile?.goal,
    level: profile?.fitnessLevel,
    age: rawAge is int ? rawAge : null,
  );
});

/// Everything the guided session needs for one plan day.
class SessionPlan {
  const SessionPlan({
    required this.plan,
    required this.day,
    required this.items,
    required this.notes,
  });

  final WorkoutPlan plan;
  final PlanDay day;
  final List<SessionItem> items;
  final List<AdaptationNote> notes;
}

/// Plan day resolved for a session, adapted to the user's conditions.
final sessionPlanProvider =
    FutureProvider.family<SessionPlan?, String>((ref, dayId) async {
  ref.watch(myPlansProvider);
  final plan = await ref.watch(workoutRepositoryProvider).getPlanByDayId(dayId);
  if (plan == null) return null;
  final library = await ref.watch(exerciseLibraryProvider.future);
  final tags = ref.watch(selectedConditionTagsProvider);
  final result = adaptPlanForConditions(plan, tags, library);
  final day = result.plan.days.firstWhere(
    (d) => d.id == dayId,
    orElse: () => plan.days.firstWhere((d) => d.id == dayId),
  );
  final byId = {for (final e in library) e.id: e};
  final items = <SessionItem>[
    for (final pe in day.exercises)
      if (byId[pe.exerciseId] != null)
        SessionItem(exercise: byId[pe.exerciseId]!, prescription: pe),
  ];
  return SessionPlan(
    plan: result.plan,
    day: day,
    items: items,
    notes: result.notes.where((n) => n.dayNumber == day.dayNumber).toList(),
  );
});
