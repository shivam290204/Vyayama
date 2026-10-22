import 'package:flutter/material.dart';

import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// The 3 structured yoga categories.
enum YogaCategory {
  beginner('Basic Yoga (Beginner)', 'Foundational asanas & alignment', Icons.spa_outlined),
  intermediate('Intermediate Yoga', 'Flow, strength & balance', Icons.fitness_center_outlined),
  advanced('Advanced Yoga', 'Inversions & arm balance mastery', Icons.whatshot_outlined);

  const YogaCategory(this.label, this.subtitle, this.icon);

  final String label;
  final String subtitle;
  final IconData icon;
}

/// A structured yoga routine or flow with curated poses, breathing cues, and modifications.
@immutable
class YogaFlow {
  const YogaFlow({
    required this.id,
    required this.title,
    required this.category,
    required this.durationMinutes,
    required this.difficulty,
    required this.description,
    required this.breathingGuidance,
    required this.cautions,
    required this.modifications,
    required this.exerciseIds,
    this.videoUrl,
  });

  final String id;
  final String title;
  final YogaCategory category;
  final int durationMinutes;
  final String difficulty;
  final String description;
  final String breathingGuidance;
  final List<String> cautions;
  final List<String> modifications;
  final List<String> exerciseIds;
  final String? videoUrl;

  /// Converts the flow into a playable [WorkoutPlan] for the live session engine.
  WorkoutPlan toWorkoutPlan() {
    return WorkoutPlan(
      id: id,
      title: title,
      goal: 'maintain',
      level: difficulty.toLowerCase(),
      isSystem: true,
      days: [
        PlanDay(
          id: '${id}_day1',
          dayNumber: 1,
          name: title,
          exercises: [
            for (var i = 0; i < exerciseIds.length; i++)
              PlanExercise(
                id: '${id}_ex$i',
                exerciseId: exerciseIds[i],
                sortOrder: i,
                durationSec: (durationMinutes * 60) ~/ exerciseIds.length,
                restSec: 15,
              ),
          ],
        ),
      ],
    );
  }
}

/// Curated library of yoga flows covering Beginner (15), Intermediate (15), and Advanced (15) asanas.
abstract final class YogaCatalog {
  static const List<YogaFlow> flows = [
    // 1. Basic Yoga (Beginner) – 15 Poses
    YogaFlow(
      id: 'yoga_beginner_15',
      title: 'Beginner Yoga Foundation',
      category: YogaCategory.beginner,
      durationMinutes: 15,
      difficulty: 'Beginner',
      description:
          '15 foundational postures for grounding, joint mobility, spinal health, and breath connection.',
      breathingGuidance:
          'Slow, conscious diaphragmatic breathing. Expand ribs on inhalation, soften belly on exhalation.',
      cautions: [
        'Move mindfully between floor and standing postures.',
        'Never force knees or hips into sharp discomfort.',
      ],
      modifications: [
        'Use a yoga block or folded blanket under hips in seated poses.',
        'Keep knees gently bent in Downward Dog to protect hamstrings.',
      ],
      exerciseIds: [
        'ex_mountain_pose',
        'ex_tree_pose',
        'ex_child_pose',
        'ex_cobra_pose',
        'ex_marjaryasana',
        'ex_bitilasana',
        'ex_sukhasana',
        'ex_vajrasana',
        'ex_bridge_pose',
        'ex_makarasana',
        'ex_pavanamuktasana',
        'ex_savasana',
        'ex_baddha_konasana',
        'ex_downward_dog',
        'ex_ardha_matsyendrasana',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=v7AYKMP6rOE',
    ),

    // 2. Intermediate Yoga – 15 Poses
    YogaFlow(
      id: 'yoga_intermediate_15',
      title: 'Intermediate Yoga Flow',
      category: YogaCategory.intermediate,
      durationMinutes: 20,
      difficulty: 'Intermediate',
      description:
          'Dynamic standing flow and strengthening postures to cultivate balance, endurance, and deep hip mobility.',
      breathingGuidance:
          'Rhythmic Ujjayi breath. Keep throat softly constricted with ocean-sounding respirations.',
      cautions: [
        'Engage core to protect lumbar spine during backbends like Camel and Bow poses.',
        'Step softly into lunges and balances without locking knee joints.',
      ],
      modifications: [
        'Use yoga blocks under hands in Triangle and Half Moon poses.',
        'Use a strap between hands in Cow Face Pose if shoulder mobility is limited.',
      ],
      exerciseIds: [
        'ex_warrior_1',
        'ex_warrior_2',
        'ex_virabhadrasana_3',
        'ex_triangle_pose',
        'ex_utkatasana',
        'ex_natarajasana',
        'ex_garudasana',
        'ex_ardha_chandrasana',
        'ex_parsvakonasana',
        'ex_prasarita_padottanasana',
        'ex_dhanurasana',
        'ex_ustrasana',
        'ex_janu_sirsasana',
        'ex_gomukhasana',
        'ex_seated_forward_fold',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=b1H3xO3x_Js',
    ),

    // 3. Advanced Yoga – 15 Poses
    YogaFlow(
      id: 'yoga_advanced_15',
      title: 'Advanced Asana Mastery',
      category: YogaCategory.advanced,
      durationMinutes: 25,
      difficulty: 'Advanced',
      description:
          'Master-level inversions, arm balances, and intense hip openers for dedicated yogis seeking pinnacle practice.',
      breathingGuidance:
          'Steady, centered breath. Never hold your breath during intense arm balances or inversions.',
      cautions: [
        'Safety Warning: Practice inversions (Headstand, Handstand, Forearm Stand) against a wall or with a spotter.',
        'Avoid inversions if you have unmanaged hypertension, glaucoma, neck conditions, or vertigo.',
        'Thoroughly warm up wrists, forearms, and shoulders before arm balances.',
        'Exit the pose immediately if you feel sharp pain in wrists, shoulders, or cervical spine.',
      ],
      modifications: [
        'In Crow Pose and Side Crow, rest one toe on a block or mat to build balance confidence.',
        'In Headstand (Sirsasana), keep 80% weight on forearms, eliminating pressure on the cervical spine.',
        'In Hanumanasana (Monkey Pose), place yoga blocks beneath your hands and a bolster under the pelvic floor.',
        'In Wheel Pose (Urdhva Dhanurasana), keep feet parallel and place angled blocks under hands for wrist comfort.',
      ],
      exerciseIds: [
        'ex_bakasana',
        'ex_sirsasana',
        'ex_pincha_mayurasana',
        'ex_adho_mukha_vrksasana',
        'ex_mayurasana',
        'ex_eka_pada_rajakapotasana',
        'ex_hanumanasana',
        'ex_urdhva_dhanurasana',
        'ex_eka_pada_koundinyasana',
        'ex_astavakrasana',
        'ex_tittibhasana',
        'ex_vrschikasana',
        'ex_parsva_bakasana',
        'ex_kapotasana',
        'ex_kukkutasana',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=s-1vMbAgYWU',
    ),
  ];
}
