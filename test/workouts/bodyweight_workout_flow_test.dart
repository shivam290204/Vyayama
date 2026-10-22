import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/workouts/data/bodyweight_workout_flow.dart';
import 'package:fitbuddy/features/workouts/data/mock_workout_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BodyweightWorkoutCatalog and BodyweightWorkoutFlow - 5 Categorized Routines', () {
    test('covers exactly the 5 required workout categories in exact order', () {
      expect(BodyweightLevel.values, [
        BodyweightLevel.warmup,
        BodyweightLevel.beginner,
        BodyweightLevel.intermediate,
        BodyweightLevel.advanced,
        BodyweightLevel.cooldown,
      ]);

      expect(BodyweightWorkoutCatalog.workouts.length, 5);
      expect(BodyweightWorkoutCatalog.workouts[0].level, BodyweightLevel.warmup);
      expect(BodyweightWorkoutCatalog.workouts[1].level, BodyweightLevel.beginner);
      expect(BodyweightWorkoutCatalog.workouts[2].level, BodyweightLevel.intermediate);
      expect(BodyweightWorkoutCatalog.workouts[3].level, BodyweightLevel.advanced);
      expect(BodyweightWorkoutCatalog.workouts[4].level, BodyweightLevel.cooldown);

      expect(BodyweightWorkoutCatalog.workouts[0].title, 'Warm-up & Mobility');
      expect(BodyweightWorkoutCatalog.workouts[1].title, 'Beginner Bodyweight Workout');
      expect(BodyweightWorkoutCatalog.workouts[2].title, 'Intermediate Bodyweight Workout');
      expect(BodyweightWorkoutCatalog.workouts[3].title, 'Advanced Bodyweight Workout');
      expect(BodyweightWorkoutCatalog.workouts[4].title, 'Cool-down & Recovery');
    });

    test('1. Warm-up & Mobility contains exact 14 exercises', () {
      final warmup = BodyweightWorkoutCatalog.workouts[0];

      const expected = [
        'ex_march_in_place',
        'ex_jumping_jacks',
        'ex_arm_circles',
        'ex_shoulder_rolls',
        'ex_arm_swings',
        'ex_neck_rotations',
        'ex_hip_circles',
        'ex_hip_rotations',
        'ex_ankle_rotations',
        'ex_leg_swings',
        'ex_high_knees',
        'ex_dynamic_lunges',
        'ex_inchworm',
        'ex_bodyweight_squat',
      ];
      expect(warmup.exercises.map((e) => e.exerciseId).toList(), expected);
      expect(warmup.totalExerciseCount, 14);
    });

    test('2. Beginner Bodyweight Workout contains exact 12 exercises', () {
      final beginner = BodyweightWorkoutCatalog.workouts[1];

      const expected = [
        'ex_wall_pushups',
        'ex_knee_pushups',
        'ex_incline_pushup',
        'ex_bodyweight_squat',
        'ex_chair_squats',
        'ex_reverse_lunge',
        'ex_glute_bridge',
        'ex_calf_raise',
        'ex_bird_dog',
        'ex_knee_plank',
        'ex_dead_bug',
        'ex_standing_crunches',
      ];
      expect(beginner.exercises.map((e) => e.exerciseId).toList(), expected);
      expect(beginner.totalExerciseCount, 12);
    });

    test('3. Intermediate Bodyweight Workout contains exact 15 exercises', () {
      final intermediate = BodyweightWorkoutCatalog.workouts[2];

      const expected = [
        'ex_pushup',
        'ex_wide_pushups',
        'ex_diamond_pushups',
        'ex_decline_pushups',
        'ex_bodyweight_squat',
        'ex_sumo_squats',
        'ex_jump_squats',
        'ex_lunge',
        'ex_walking_lunges',
        'ex_bulgarian_split_squat',
        'ex_plank',
        'ex_side_plank',
        'ex_bicycle_crunch',
        'ex_mountain_climbers',
        'ex_straight_leg_raise',
      ];
      expect(intermediate.exercises.map((e) => e.exerciseId).toList(), expected);
      expect(intermediate.totalExerciseCount, 15);
    });

    test('4. Advanced Bodyweight Workout contains exact 14 exercises', () {
      final advanced = BodyweightWorkoutCatalog.workouts[3];

      const expected = [
        'ex_archer_pushups',
        'ex_explosive_pushups',
        'ex_pike_pushups',
        'ex_pseudo_planche_pushups',
        'ex_assisted_pistol_squats',
        'ex_jump_lunges',
        'ex_single_leg_squats',
        'ex_single_leg_glute_bridge',
        'ex_burpee',
        'ex_plank_to_pushup',
        'ex_v_ups',
        'ex_hanging_leg_raises',
        'ex_lsit_hold',
        'ex_handstand_pushups',
      ];
      expect(advanced.exercises.map((e) => e.exerciseId).toList(), expected);
      expect(advanced.totalExerciseCount, 14);
    });

    test('5. Cool-down & Recovery contains exact 12 exercises', () {
      final cooldown = BodyweightWorkoutCatalog.workouts[4];

      const expected = [
        'ex_child_pose',
        'ex_cobra_pose',
        'ex_downward_dog',
        'ex_quad_stretch',
        'ex_hamstring_stretch',
        'ex_hip_flexor_stretch',
        'ex_baddha_konasana',
        'ex_chest_stretch',
        'ex_shoulder_stretch',
        'ex_overhead_triceps_stretch',
        'ex_seated_forward_fold',
        'ex_deep_breathing',
      ];
      expect(cooldown.exercises.map((e) => e.exerciseId).toList(), expected);
      expect(cooldown.totalExerciseCount, 12);
    });

    test('every exercise has prescriptions and easier modifications where appropriate', () {
      for (final workout in BodyweightWorkoutCatalog.workouts) {
        for (final ex in workout.exercises) {
          expect(ex.exerciseId, isNotEmpty);
          expect(ex.name, isNotEmpty);
          expect(
            ex.reps != null || ex.durationSec != null,
            isTrue,
            reason: '${ex.name} in ${workout.title} must have reps or duration',
          );
          expect(ex.restSec, greaterThanOrEqualTo(0));
          expect(ex.easierModification, isNotNull);
          expect(ex.easierModification, isNotEmpty);
        }
      }
    });

    test('every exerciseId across all 5 routines exists in exercises.json with valid disk assets', () {
      final file = File('assets/data/exercises.json');
      expect(file.existsSync(), isTrue);

      final jsonContent = file.readAsStringSync();
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final exercisesList = decoded['exercises'] as List<dynamic>;
      final exerciseMap = {
        for (final e in exercisesList) e['id'] as String: e as Map<String, dynamic>,
      };

      for (final workout in BodyweightWorkoutCatalog.workouts) {
        for (final ex in workout.exercises) {
          final dbEx = exerciseMap[ex.exerciseId];
          expect(
            dbEx,
            isNotNull,
            reason: '${ex.exerciseId} (${ex.name}) in ${workout.title} must exist in exercises.json',
          );

          final assetPath = dbEx!['animation_asset'] as String?;
          expect(
            assetPath,
            isNotNull,
            reason: '${ex.exerciseId} must have an animation_asset defined',
          );

          final assetFile = File(assetPath!);
          expect(
            assetFile.existsSync(),
            isTrue,
            reason: 'Asset file $assetPath for ${ex.name} must exist on disk',
          );

          final videoUrl = dbEx['video_url'] as String?;
          expect(
            videoUrl,
            isNotNull,
            reason: '${ex.exerciseId} (${ex.name}) must have a valid video_url',
          );
          expect(videoUrl!.startsWith('https://www.youtube.com/watch?v='), isTrue);
        }
      }
    });

    test('all 5 bodyweight workouts are registered in workout_plans.json', () {
      final file = File('assets/data/workout_plans.json');
      expect(file.existsSync(), isTrue);

      final jsonContent = file.readAsStringSync();
      final decoded = json.decode(jsonContent) as Map<String, dynamic>;
      final plansList = decoded['plans'] as List<dynamic>;
      final planIds = plansList.map((p) => p['id'] as String).toSet();

      for (final flow in BodyweightWorkoutCatalog.workouts) {
        expect(
          planIds.contains(flow.id),
          isTrue,
          reason: '${flow.id} must be registered in workout_plans.json',
        );
      }
    });

    test('toWorkoutPlan converts flow to playable WorkoutPlan and resolves in MockWorkoutRepository', () async {
      final repo = MockWorkoutRepository();

      for (final flow in BodyweightWorkoutCatalog.workouts) {
        final plan = flow.toWorkoutPlan();
        expect(plan.id, flow.id);
        expect(plan.days.length, 1);
        expect(plan.days.first.exercises.length, flow.totalExerciseCount);

        final fetchedPlan = await repo.getPlan(flow.id);
        expect(fetchedPlan, isNotNull);
        expect(fetchedPlan!.id, flow.id);

        final fetchedPlanByDay = await repo.getPlanByDayId('${flow.id}_session');
        expect(fetchedPlanByDay, isNotNull);
        expect(fetchedPlanByDay!.days.first.exercises.length, flow.totalExerciseCount);
      }
    });

    test('findContext correctly resolves category and exercise context', () {
      final warmupCtx = BodyweightWorkoutCatalog.findContext(
        planDayId: 'workout_warmup_mobility_session',
        exerciseId: 'ex_jumping_jacks',
      );
      expect(warmupCtx, isNotNull);
      expect(warmupCtx!.phase, WorkoutSectionType.warmup);
      expect(warmupCtx.item.name, 'Jumping Jacks');
      expect(warmupCtx.phaseIndex, 2);
      expect(warmupCtx.phaseTotal, 14);

      final beginnerCtx = BodyweightWorkoutCatalog.findContext(
        planDayId: 'bodyweight_beginner_session',
        exerciseId: 'ex_wall_pushups',
      );
      expect(beginnerCtx, isNotNull);
      expect(beginnerCtx!.phase, WorkoutSectionType.main);
      expect(beginnerCtx.item.name, 'Wall Push-ups');

      final intermediateCtx = BodyweightWorkoutCatalog.findContext(
        planDayId: 'bodyweight_intermediate_session',
        exerciseId: 'ex_pushup',
      );
      expect(intermediateCtx, isNotNull);
      expect(intermediateCtx!.phase, WorkoutSectionType.main);
      expect(intermediateCtx.item.name, 'Standard Push-ups');

      final advancedCtx = BodyweightWorkoutCatalog.findContext(
        planDayId: 'bodyweight_advanced_session',
        exerciseId: 'ex_archer_pushups',
      );
      expect(advancedCtx, isNotNull);
      expect(advancedCtx!.phase, WorkoutSectionType.main);
      expect(advancedCtx.item.name, 'Archer Push-ups');

      final coolCtx = BodyweightWorkoutCatalog.findContext(
        planDayId: 'workout_cooldown_recovery_session',
        exerciseId: 'ex_child_pose',
      );
      expect(coolCtx, isNotNull);
      expect(coolCtx!.phase, WorkoutSectionType.cooldown);
      expect(coolCtx.item.name, "Child's Pose");
    });
  });
}
