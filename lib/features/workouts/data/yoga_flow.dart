import 'package:flutter/material.dart';

import 'package:fitbuddy/features/workouts/data/workout_plan.dart';

/// The 7 structured yoga categories.
enum YogaCategory {
  beginner('Beginner Yoga', 'Gentle foundation & 15 basic asanas', Icons.spa_outlined),
  intermediate('Intermediate Yoga', 'Flow, strength & 15 intermediate asanas', Icons.fitness_center_outlined),
  advanced('Advanced Yoga', 'Inversions, arm balances & 15 peak asanas', Icons.whatshot_outlined),
  morning('Morning Flow', 'Wake-up energy & spine awakening', Icons.wb_sunny_outlined),
  relaxation('Relaxation & Sleep', 'Evening wind-down & nervous system calm', Icons.bedtime_outlined),
  flexibility('Flexibility & Mobility', 'Deep hip & hamstring opening', Icons.self_improvement_outlined),
  balance('Balance & Stability', 'Core control & joint stability', Icons.accessibility_new_outlined);

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

/// Curated library of yoga flows covering Beginner (15), Intermediate (15), Advanced (15) and specialized flows.
abstract final class YogaCatalog {
  static const List<YogaFlow> flows = [
    // 1. Beginner Yoga (15 Poses)
    YogaFlow(
      id: 'yoga_beginner_15',
      title: 'Beginner Yoga Foundation (15 Asanas)',
      category: YogaCategory.beginner,
      durationMinutes: 15,
      difficulty: 'Beginner',
      description:
          '15 foundational postures: Tadasana, Vrikshasana, Balasana, Bhujangasana, Marjaryasana, Bitilasana, Sukhasana, Vajrasana, Setu Bandhasana, Makarasana, Pavanamuktasana, Shavasana, Baddha Konasana, Downward Dog, and Half Spinal Twist.',
      breathingGuidance:
          'Slow, conscious diaphragmatic breathing. Expand ribs on inhalation, soften belly on exhalation.',
      cautions: [
        'Move slowly between floor and standing poses.',
        'Never force knees into deep flexion.',
      ],
      modifications: [
        'Place a folded blanket under hips in Sukhasana or under knees in tabletop.',
        'Keep knees bent in Downward Dog if hamstrings are tight.',
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
        'ex_baddha_konasana',
        'ex_downward_dog',
        'ex_ardha_matsyendrasana',
        'ex_savasana',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=v7AYKMP6rOE',
    ),

    // 2. Intermediate Yoga (15 Poses)
    YogaFlow(
      id: 'yoga_intermediate_15',
      title: 'Intermediate Flow & Power (15 Asanas)',
      category: YogaCategory.intermediate,
      durationMinutes: 20,
      difficulty: 'Intermediate',
      description:
          '15 dynamic strengthening postures: Virabhadrasana I, II, III, Trikonasana, Utkatasana, Natarajasana, Garudasana, Ardha Chandrasana, Parsvakonasana, Wide Fold, Dhanurasana, Ustrasana, Janu Sirsasana, Gomukhasana, and Paschimottanasana.',
      breathingGuidance:
          'Rhythmic Ujjayi breath. Keep throat softly constricted with ocean-sounding respirations.',
      cautions: [
        'Keep core engaged to protect lumbar spine during Camel and Bow poses.',
        'Step gently back without hyperextending knees.',
      ],
      modifications: [
        'Use yoga blocks under hands in Triangle and Half Moon poses.',
        'Use a strap between hands in Cow Face Pose if shoulders are tight.',
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

    // 3. Advanced Yoga (15 Poses)
    YogaFlow(
      id: 'yoga_advanced_15',
      title: 'Advanced Asana Mastery (15 Asanas)',
      category: YogaCategory.advanced,
      durationMinutes: 25,
      difficulty: 'Advanced',
      description:
          '15 master-level inversions and arm balances: Bakasana, Sirsasana, Pincha Mayurasana, Handstand, Mayurasana, King Pigeon, Hanumanasana, Wheel, Flying Splits, Astavakrasana, Firefly, Scorpion, Side Crow, Kapotasana, and Kukkutasana.',
      breathingGuidance:
          'Steady, centered breath. Never hold breath during intense arm balances or inversions.',
      cautions: [
        'Practice with wall support or spotter for headstand, handstand, and forearm balances.',
        'Warm up wrists thoroughly before arm balances.',
      ],
      modifications: [
        'Start with one foot grounded on a block in Crow Pose.',
        'Use blocks under hands in Hanumanasana (splits) to reduce hamstring strain.',
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
      videoUrl: 'https://www.youtube.com/watch?v=J5v9o_4i7qA',
    ),

    // 4. Morning Energy Flow
    YogaFlow(
      id: 'yoga_morning_wakeup',
      title: 'Morning Sun Energy Flow',
      category: YogaCategory.morning,
      durationMinutes: 8,
      difficulty: 'Beginner',
      description:
          'Gently awakens the nervous system, shakes off sleep stiffness, and boosts circulation.',
      breathingGuidance:
          'Deep, energizing inhalations to greet the morning. Exhale any lingering tiredness.',
      cautions: [
        'Move gently through early morning backbends before muscles are warm.',
      ],
      modifications: [
        'Keep knees generously bent in Downward Dog to ease morning lower back stiffness.',
      ],
      exerciseIds: [
        'ex_mountain_pose',
        'ex_marjaryasana',
        'ex_bitilasana',
        'ex_downward_dog',
        'ex_child_pose',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=4pKly2JojMw',
    ),

    // 5. Evening Relaxation & Sleep
    YogaFlow(
      id: 'yoga_evening_relaxation',
      title: 'Evening Calm & Restful Sleep',
      category: YogaCategory.relaxation,
      durationMinutes: 12,
      difficulty: 'Beginner',
      description:
          'Downregulates the sympathetic nervous system and releases shoulder and lower back tension.',
      breathingGuidance:
          'Extended 4-second inhale with prolonged 6-second exhale to trigger parasympathetic calm.',
      cautions: [
        'Keep lighting soft and temperature comfortable.',
        'Release all muscular effort in final resting posture.',
      ],
      modifications: [
        'Rest knees on pillows or bolster in Savasana to relieve lower back pressure.',
        'Widen knees in Child Pose to make space for the abdomen.',
      ],
      exerciseIds: [
        'ex_child_pose',
        'ex_pavanamuktasana',
        'ex_seated_forward_fold',
        'ex_bridge_pose',
        'ex_savasana',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=BiWDsfZ3zbo',
    ),

    // 6. Deep Flexibility & Mobility
    YogaFlow(
      id: 'yoga_flexibility_mobility',
      title: 'Deep Hip & Spine Mobility',
      category: YogaCategory.flexibility,
      durationMinutes: 15,
      difficulty: 'All Levels',
      description:
          'Targeted holds to release hip flexor tension, tight hamstrings, and thoracic stiffness.',
      breathingGuidance:
          'Direct breath into tight areas. On each exhale, allow muscles to soften without bouncing.',
      cautions: [
        'Never force a joint into sharp pain. Stay in the gentle tension zone.',
      ],
      modifications: [
        'Use a strap or towel around feet in Seated Forward Fold.',
        'Keep hands elevated on yoga blocks during lunges.',
      ],
      exerciseIds: [
        'ex_baddha_konasana',
        'ex_downward_dog',
        'ex_triangle_pose',
        'ex_ardha_matsyendrasana',
        'ex_child_pose',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=g_tea8ZNk5A',
    ),

    // 7. Balance & Stability
    YogaFlow(
      id: 'yoga_balance_stability',
      title: 'Balance & Core Centering',
      category: YogaCategory.balance,
      durationMinutes: 10,
      difficulty: 'Intermediate',
      description:
          'Cultivates single-leg stability, proprioception, and rotational core engagement.',
      breathingGuidance:
          'Smooth, unhurried breathing. Fixing gaze (Drishti) on an unmoving spot stabilizes balance.',
      cautions: [
        'Practice near a wall if you experience vertigo or balance instability.',
      ],
      modifications: [
        'Keep toes of lifted foot lightly touching floor as a kickstand.',
        'Place one hand on a wall during Tree Pose.',
      ],
      exerciseIds: [
        'ex_mountain_pose',
        'ex_tree_pose',
        'ex_warrior_2',
        'ex_virabhadrasana_3',
        'ex_child_pose',
      ],
      videoUrl: 'https://www.youtube.com/watch?v=fK_hI53_q6E',
    ),
  ];
}
