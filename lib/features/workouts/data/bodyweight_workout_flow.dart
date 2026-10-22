import 'package:flutter/material.dart';

import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// Difficulty level / routine category for the 5 structured Bodyweight Workouts.
enum BodyweightLevel {
  warmup('Warm-up', 'Warm-up & Mobility', Icons.wb_sunny_rounded, Color(0xFF0D9488)),
  beginner('Beginner', 'Beginner Bodyweight Workout', Icons.directions_walk_rounded, Color(0xFF2E7D32)),
  intermediate('Intermediate', 'Intermediate Bodyweight Workout', Icons.fitness_center_rounded, Color(0xFFD97706)),
  advanced('Advanced', 'Advanced Bodyweight Workout', Icons.whatshot_rounded, Color(0xFFC2410C)),
  cooldown('Cool-down', 'Cool-down & Recovery', Icons.spa_rounded, Color(0xFF2563EB));

  const BodyweightLevel(this.difficulty, this.title, this.icon, this.color);

  final String difficulty;
  final String title;
  final IconData icon;
  final Color color;
}

/// The category types for the 5 workouts.
enum WorkoutSectionType {
  warmup('Warm-up', 'Prepare joints and elevate body temperature', Icons.wb_sunny_rounded, Color(0xFFFF9800)),
  main('Main Workout', 'Strength, endurance and technique work', Icons.fitness_center_rounded, Color(0xFF00C853)),
  cooldown('Cool-down', 'Static stretching and recovery', Icons.self_improvement_rounded, Color(0xFF00B4D8));

  const WorkoutSectionType(this.label, this.subtitle, this.icon, this.color);

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

/// One exercise prescription within a workout category.
@immutable
class BodyweightExerciseItem {
  const BodyweightExerciseItem({
    required this.exerciseId,
    required this.name,
    this.sets = 1,
    this.reps,
    this.durationSec,
    this.restSec = 30,
    this.easierModification,
  });

  final String exerciseId;
  final String name;
  final int sets;
  final int? reps;
  final int? durationSec;
  final int restSec;
  final String? easierModification;

  bool get isTimed => (durationSec ?? 0) > 0;
}

/// A structured Bodyweight Workout plan for each of the 5 categories.
@immutable
class BodyweightWorkoutFlow {
  const BodyweightWorkoutFlow({
    required this.id,
    required this.level,
    required this.sectionType,
    required this.title,
    required this.badge,
    required this.description,
    required this.estimatedDuration,
    required this.illustrationAsset,
    required this.exercises,
  });

  final String id;
  final BodyweightLevel level;
  final WorkoutSectionType sectionType;
  final String title;
  final String badge;
  final String description;
  final String estimatedDuration;
  final String illustrationAsset;
  final List<BodyweightExerciseItem> exercises;

  /// Total count of all exercises in this routine.
  int get totalExerciseCount => exercises.length;

  /// Ordered list of all exercise items in this routine.
  List<BodyweightExerciseItem> get allExercises => exercises;

  /// Backwards-compatibility helpers for phase queries
  List<BodyweightExerciseItem> get warmupExercises =>
      sectionType == WorkoutSectionType.warmup ? exercises : const [];
  List<BodyweightExerciseItem> get mainExercises =>
      sectionType == WorkoutSectionType.main ? exercises : const [];
  List<BodyweightExerciseItem> get cooldownExercises =>
      sectionType == WorkoutSectionType.cooldown ? exercises : const [];

  /// Maps the flow into a playable [WorkoutPlan] for the guided session engine.
  WorkoutPlan toWorkoutPlan() {
    return WorkoutPlan(
      id: id,
      title: title,
      goal: 'maintain',
      level: level.difficulty.toLowerCase(),
      isSystem: true,
      days: [
        PlanDay(
          id: '${id}_session',
          dayNumber: 1,
          name: title,
          exercises: [
            for (var i = 0; i < exercises.length; i++)
              PlanExercise(
                id: '${id}_item_$i',
                exerciseId: exercises[i].exerciseId,
                sortOrder: i,
                sets: exercises[i].sets,
                reps: exercises[i].reps,
                durationSec: exercises[i].durationSec,
                restSec: exercises[i].restSec,
              ),
          ],
        ),
      ],
    );
  }
}

/// The official catalog of the 5 structured Bodyweight Workouts in exact order:
/// 1. Warm-up & Mobility
/// 2. Beginner Bodyweight Workout
/// 3. Intermediate Bodyweight Workout
/// 4. Advanced Bodyweight Workout
/// 5. Cool-down & Recovery
abstract final class BodyweightWorkoutCatalog {
  static const List<BodyweightWorkoutFlow> workouts = [
    // -------------------------------------------------------------
    // 1. Warm-up & Mobility
    // -------------------------------------------------------------
    BodyweightWorkoutFlow(
      id: 'workout_warmup_mobility',
      level: BodyweightLevel.warmup,
      sectionType: WorkoutSectionType.warmup,
      title: 'Warm-up & Mobility',
      badge: 'Warm-up',
      description:
          'Prime your joints, activate key muscle groups, and elevate core temperature before any workout.',
      estimatedDuration: '10–12 minutes',
      illustrationAsset: 'assets/exercises/arm_swings.png',
      exercises: [
        BodyweightExerciseItem(
          exerciseId: 'ex_march_in_place',
          name: 'Marching in Place',
          durationSec: 60,
          restSec: 10,
          easierModification: 'March at a gentle rhythm with hand resting on a wall for balance.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_jumping_jacks',
          name: 'Jumping Jacks',
          durationSec: 45,
          restSec: 10,
          easierModification: 'Perform low-impact Step Jacks by stepping one foot out at a time without jumping.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_arm_circles',
          name: 'Arm Circles',
          durationSec: 40,
          restSec: 10,
          easierModification: 'Make smaller, controlled circles and rest your arms as needed.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_shoulder_rolls',
          name: 'Shoulder Rolls',
          durationSec: 40,
          restSec: 10,
          easierModification: 'Roll shoulders slowly while seated or standing without forcing range of motion.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_arm_swings',
          name: 'Arm Swings',
          durationSec: 40,
          restSec: 10,
          easierModification: 'Swing arms gently across your chest within a comfortable, pain-free range.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_neck_rotations',
          name: 'Neck Rotations (gentle)',
          durationSec: 40,
          restSec: 10,
          easierModification: 'Gently tilt head from side to side rather than full 360-degree rolls.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_hip_circles',
          name: 'Hip Circles',
          durationSec: 45,
          restSec: 10,
          easierModification: 'Keep circles smaller and place hands on hips or hold a stable chair.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_hip_rotations',
          name: 'Hip Rotations',
          durationSec: 45,
          restSec: 10,
          easierModification: 'Keep hands on a wall for support and lift knees to a lower, comfortable height.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_ankle_rotations',
          name: 'Ankle Rotations',
          durationSec: 45,
          restSec: 10,
          easierModification: 'Sit in a chair and rotate each ankle gently in both directions.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_leg_swings',
          name: 'Leg Swings',
          durationSec: 45,
          restSec: 10,
          easierModification: 'Hold firmly onto a wall or sturdy rail and swing legs through a smaller arc.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_high_knees',
          name: 'High Knees',
          durationSec: 40,
          restSec: 15,
          easierModification: 'March in place lifting knees waist-high without jumping.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_dynamic_lunges',
          name: 'Dynamic Lunges',
          reps: 12,
          restSec: 15,
          easierModification: 'Take shallower lunges and hold a chair or wall for steady support.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_inchworm',
          name: 'Inchworms',
          reps: 8,
          restSec: 15,
          easierModification: 'Bend your knees generously when reaching for the floor.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_bodyweight_squat',
          name: 'Bodyweight Squats',
          reps: 12,
          restSec: 20,
          easierModification: 'Squat to a chair or bench to ensure balanced, controlled depth.',
        ),
      ],
    ),

    // -------------------------------------------------------------
    // 2. Beginner Bodyweight Workout
    // -------------------------------------------------------------
    BodyweightWorkoutFlow(
      id: 'bodyweight_beginner',
      level: BodyweightLevel.beginner,
      sectionType: WorkoutSectionType.main,
      title: 'Beginner Bodyweight Workout',
      badge: 'Beginner',
      description:
          'Build basic fitness, learn correct exercise techniques, and develop consistency.',
      estimatedDuration: '20–25 minutes',
      illustrationAsset: 'assets/exercises/incline_pushup.png',
      exercises: [
        BodyweightExerciseItem(
          exerciseId: 'ex_wall_pushups',
          name: 'Wall Push-ups',
          reps: 12,
          restSec: 30,
          easierModification: 'Stand closer to the wall to decrease the angle and resistance.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_knee_pushups',
          name: 'Knee Push-ups',
          reps: 10,
          restSec: 30,
          easierModification: 'Place knees closer under hips (box push-up) or return to wall push-ups.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_incline_pushup',
          name: 'Incline Push-ups',
          reps: 10,
          restSec: 30,
          easierModification: 'Use a higher elevation such as a sturdy dining table or kitchen counter.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_bodyweight_squat',
          name: 'Bodyweight Squats',
          reps: 12,
          restSec: 30,
          easierModification: 'Hold onto a doorway or counter for gentle balance assistance.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_chair_squats',
          name: 'Chair Squats',
          reps: 10,
          restSec: 30,
          easierModification: 'Use armrests to assist standing up or add a firm cushion for higher seat height.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_reverse_lunge',
          name: 'Reverse Lunges',
          reps: 10,
          restSec: 30,
          easierModification: 'Step back into a shallow split stance without dropping the rear knee too low.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_glute_bridge',
          name: 'Glute Bridges',
          reps: 12,
          restSec: 30,
          easierModification: 'Keep hands flat on the floor beside you and elevate hips only as high as comfortable.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_calf_raise',
          name: 'Standing Calf Raises',
          reps: 15,
          restSec: 30,
          easierModification: 'Perform seated calf raises or lightly rest hands against a wall for support.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_bird_dog',
          name: 'Bird Dog',
          reps: 10,
          restSec: 30,
          easierModification: 'Extend only one limb at a time (leg first, then arm) instead of opposites together.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_knee_plank',
          name: 'Knee Plank',
          durationSec: 30,
          restSec: 30,
          easierModification: 'Elevate forearms onto a sturdy couch or hold for 10-second intervals.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_dead_bug',
          name: 'Dead Bug',
          reps: 10,
          restSec: 30,
          easierModification: 'Move only the arms or only tap heels down while keeping knees bent at 90 degrees.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_standing_crunches',
          name: 'Standing Crunches',
          reps: 12,
          restSec: 30,
          easierModification: 'Lift knees waist-high with hands on hips instead of touching elbows.',
        ),
      ],
    ),

    // -------------------------------------------------------------
    // 3. Intermediate Bodyweight Workout
    // -------------------------------------------------------------
    BodyweightWorkoutFlow(
      id: 'bodyweight_intermediate',
      level: BodyweightLevel.intermediate,
      sectionType: WorkoutSectionType.main,
      title: 'Intermediate Bodyweight Workout',
      badge: 'Intermediate',
      description:
          'Improve strength, stamina, and muscular endurance with more challenging bodyweight exercises.',
      estimatedDuration: '30–35 minutes',
      illustrationAsset: 'assets/exercises/pushup.png',
      exercises: [
        BodyweightExerciseItem(
          exerciseId: 'ex_pushup',
          name: 'Standard Push-ups',
          reps: 12,
          restSec: 30,
          easierModification: 'Elevate hands on a bench or drop to knees for the final repetitions.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_wide_pushups',
          name: 'Wide-Grip Push-ups',
          reps: 10,
          restSec: 30,
          easierModification: 'Perform on an elevated surface or from your knees with hands slightly wider than shoulders.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_diamond_pushups',
          name: 'Diamond Push-ups',
          reps: 8,
          restSec: 30,
          easierModification: 'Widen hands slightly so thumbs touch or perform with hands elevated on a bench.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_decline_pushups',
          name: 'Decline Push-ups',
          reps: 10,
          restSec: 30,
          easierModification: 'Use a lower elevation for feet (e.g. a 2-4 inch step) or perform flat push-ups.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_bodyweight_squat',
          name: 'Standard Squats',
          reps: 15,
          restSec: 30,
          easierModification: 'Slow down the descent (3 seconds down) and squat to parallel.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_sumo_squats',
          name: 'Sumo Squats',
          reps: 15,
          restSec: 30,
          easierModification: 'Narrow the stance slightly and hold a counter for balance if hips feel tight.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_jump_squats',
          name: 'Jump Squats',
          reps: 10,
          restSec: 40,
          easierModification: 'Perform rapid-tempo bodyweight squats without the jump (speed squats).',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_lunge',
          name: 'Forward Lunges',
          reps: 12,
          restSec: 30,
          easierModification: 'Step backward into reverse lunges to reduce shear stress on the front knee.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_walking_lunges',
          name: 'Walking Lunges',
          reps: 14,
          restSec: 30,
          easierModification: 'Do stationary reverse lunges or take shorter walking strides.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_bulgarian_split_squat',
          name: 'Bulgarian Split Squats',
          reps: 8,
          restSec: 40,
          easierModification: 'Place rear foot flat on the floor instead of elevated (static split squat).',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_plank',
          name: 'Plank',
          durationSec: 45,
          restSec: 30,
          easierModification: 'Hold for three 15-second blocks with brief 3-second rests in between.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_side_plank',
          name: 'Side Plank',
          durationSec: 30,
          restSec: 30,
          easierModification: 'Bend bottom knee at 90 degrees and support weight on knee and forearm.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_bicycle_crunch',
          name: 'Bicycle Crunches',
          reps: 16,
          restSec: 30,
          easierModification: 'Keep feet flat on floor and perform alternating diagonal reach crunches.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_mountain_climbers',
          name: 'Mountain Climbers',
          durationSec: 30,
          restSec: 30,
          easierModification: 'Step one foot in at a time at a measured walking pace instead of running.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_straight_leg_raise',
          name: 'Leg Raises',
          reps: 12,
          restSec: 30,
          easierModification: 'Bend knees at 90 degrees (bent-knee leg raises) to reduce lower back load.',
        ),
      ],
    ),

    // -------------------------------------------------------------
    // 4. Advanced Bodyweight Workout
    // -------------------------------------------------------------
    BodyweightWorkoutFlow(
      id: 'bodyweight_advanced',
      level: BodyweightLevel.advanced,
      sectionType: WorkoutSectionType.main,
      title: 'Advanced Bodyweight Workout',
      badge: 'Advanced',
      description:
          'Maximize relative strength, power, and athletic control through high-level calisthenics.',
      estimatedDuration: '40–45 minutes',
      illustrationAsset: 'assets/exercises/archer_pushup.png',
      exercises: [
        BodyweightExerciseItem(
          exerciseId: 'ex_archer_pushups',
          name: 'Archer Push-ups',
          reps: 8,
          restSec: 45,
          easierModification: 'Perform with hands on an elevated surface or slightly bent extending arm.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_explosive_pushups',
          name: 'Explosive Push-ups',
          reps: 8,
          restSec: 45,
          easierModification: 'Push aggressively off hands without leaving the floor completely.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_pike_pushups',
          name: 'Pike Push-ups',
          reps: 10,
          restSec: 45,
          easierModification: 'Walk feet slightly further back to decrease shoulder load or elevate hands on a step.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_pseudo_planche_pushups',
          name: 'Pseudo Planche Push-ups',
          reps: 8,
          restSec: 45,
          easierModification: 'Lean forward slightly less or perform push-ups from the knees with forward lean.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_assisted_pistol_squats',
          name: 'Pistol Squats',
          reps: 6,
          restSec: 45,
          easierModification: 'Hold onto a doorframe, pole, or resistance band for balance assistance.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_jump_lunges',
          name: 'Jump Lunges',
          reps: 12,
          restSec: 45,
          easierModification: 'Perform rapid alternating reverse lunges without jumping.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_single_leg_squats',
          name: 'Single-Leg Squats',
          reps: 6,
          restSec: 45,
          easierModification: 'Squat down to sit on a chair or bench before standing back up.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_single_leg_glute_bridge',
          name: 'Single-Leg Glute Bridges',
          reps: 10,
          restSec: 45,
          easierModification: 'Place non-working heel lightly on the floor for 10% assistance.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_burpee',
          name: 'Burpees',
          reps: 12,
          restSec: 45,
          easierModification: 'Step back into a plank instead of jumping and omit the push-up.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_plank_to_pushup',
          name: 'Plank to Push-up',
          reps: 10,
          restSec: 45,
          easierModification: 'Perform the transition from your knees while keeping your core solid.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_v_ups',
          name: 'V-ups',
          reps: 12,
          restSec: 45,
          easierModification: 'Tuck knees to chest (Tuck-ups) instead of keeping legs completely straight.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_hanging_leg_raises',
          name: 'Hanging Leg Raises (if a bar is available)',
          reps: 10,
          restSec: 45,
          easierModification: 'Perform hanging knee raises (bend knees to 90 degrees) or lying leg raises.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_lsit_hold',
          name: 'L-sit Hold',
          durationSec: 20,
          restSec: 45,
          easierModification: 'Tuck both knees to chest (tuck L-sit) or extend one leg at a time.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_handstand_pushups',
          name: 'Handstand Push-up Progression',
          reps: 6,
          restSec: 60,
          easierModification: 'Perform elevated feet pike push-ups with toes on a sturdy chair.',
        ),
      ],
    ),

    // -------------------------------------------------------------
    // 5. Cool-down & Recovery
    // -------------------------------------------------------------
    BodyweightWorkoutFlow(
      id: 'workout_cooldown_recovery',
      level: BodyweightLevel.cooldown,
      sectionType: WorkoutSectionType.cooldown,
      title: 'Cool-down & Recovery',
      badge: 'Cool-down',
      description:
          'Aid muscle recovery, lower heart rate safely, improve flexibility, and reduce soreness.',
      estimatedDuration: '10–15 minutes',
      illustrationAsset: 'assets/exercises/child_pose.png',
      exercises: [
        BodyweightExerciseItem(
          exerciseId: 'ex_child_pose',
          name: "Child's Pose",
          durationSec: 45,
          restSec: 15,
          easierModification: 'Place a folded blanket under knees or a pillow between hips and heels.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_cobra_pose',
          name: 'Cobra Stretch',
          durationSec: 35,
          restSec: 15,
          easierModification: 'Rest on forearms (Sphinx Pose) instead of pressing up onto palms.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_downward_dog',
          name: 'Downward-Facing Dog',
          durationSec: 40,
          restSec: 15,
          easierModification: 'Keep knees generously bent and focus on lengthening the spine and pressing chest through.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_quad_stretch',
          name: 'Standing Quad Stretch',
          durationSec: 30,
          restSec: 15,
          easierModification: 'Rest non-stretching hand on a wall and loop a towel around your foot if needed.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_hamstring_stretch',
          name: 'Hamstring Stretch',
          durationSec: 35,
          restSec: 15,
          easierModification: 'Use a towel or strap looped around foot or keep a slight bend in the knee.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_hip_flexor_stretch',
          name: 'Hip Flexor Stretch',
          durationSec: 35,
          restSec: 15,
          easierModification: 'Place a soft cushion under the rear kneeling knee and keep hands on front thigh.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_baddha_konasana',
          name: 'Butterfly Stretch',
          durationSec: 40,
          restSec: 15,
          easierModification: 'Sit elevated on a yoga block or cushion to alleviate hip tension.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_chest_stretch',
          name: 'Chest Stretch',
          durationSec: 35,
          restSec: 15,
          easierModification: 'Place forearm against a wall corner and rotate body gently away.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_shoulder_stretch',
          name: 'Shoulder Stretch',
          durationSec: 30,
          restSec: 15,
          easierModification: 'Hold the stretch without pulling tightly across the throat.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_overhead_triceps_stretch',
          name: 'Triceps Stretch',
          durationSec: 30,
          restSec: 15,
          easierModification: 'Gently push the elbow from the front instead of pulling overhead if shoulders are stiff.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_seated_forward_fold',
          name: 'Seated Forward Bend',
          durationSec: 45,
          restSec: 15,
          easierModification: 'Bend knees softly and reach for shins or ankles instead of feet.',
        ),
        BodyweightExerciseItem(
          exerciseId: 'ex_deep_breathing',
          name: 'Deep Breathing',
          durationSec: 60,
          restSec: 0,
          easierModification: 'Lie flat on your back with knees bent and one hand resting on your belly.',
        ),
      ],
    ),
  ];

  /// Resolves the contextual phase and guidance for an active session.
  static BodyweightExerciseContext? findContext({
    String? planDayId,
    required String exerciseId,
    int? index,
  }) {
    if (exerciseId.isEmpty) return null;

    BodyweightWorkoutFlow? flow;
    if (planDayId != null && planDayId.isNotEmpty) {
      for (final w in workouts) {
        if (planDayId.startsWith(w.id) ||
            planDayId == '${w.id}_session' ||
            planDayId == w.id) {
          flow = w;
          break;
        }
      }
    }

    flow ??= workouts.firstWhere(
      (w) => w.exercises.any((e) => e.exerciseId == exerciseId),
      orElse: () => workouts.first,
    );

    int idx = (index != null &&
            index >= 0 &&
            index < flow.exercises.length &&
            flow.exercises[index].exerciseId == exerciseId)
        ? index
        : flow.exercises.indexWhere((e) => e.exerciseId == exerciseId);

    if (idx != -1) {
      return BodyweightExerciseContext(
        workout: flow,
        phase: flow.sectionType,
        item: flow.exercises[idx],
        phaseIndex: idx + 1,
        phaseTotal: flow.exercises.length,
      );
    }
    return null;
  }
}

/// Contextual info about an active exercise inside a structured bodyweight workout.
@immutable
class BodyweightExerciseContext {
  const BodyweightExerciseContext({
    required this.workout,
    required this.phase,
    required this.item,
    required this.phaseIndex,
    required this.phaseTotal,
  });

  final BodyweightWorkoutFlow workout;
  final WorkoutSectionType phase;
  final BodyweightExerciseItem item;
  final int phaseIndex;
  final int phaseTotal;
}
