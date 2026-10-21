import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/workouts/data/yoga_flow.dart';

void main() {
  group('YogaCatalog and YogaFlow - 3 Strict Sections', () {
    test('covers exactly the 3 required yoga categories in exact order', () {
      expect(YogaCategory.values, [
        YogaCategory.beginner,
        YogaCategory.intermediate,
        YogaCategory.advanced,
      ]);

      expect(YogaCatalog.flows.length, 3);
      expect(YogaCatalog.flows[0].category, YogaCategory.beginner);
      expect(YogaCatalog.flows[1].category, YogaCategory.intermediate);
      expect(YogaCatalog.flows[2].category, YogaCategory.advanced);

      expect(YogaCatalog.flows[0].title, 'Beginner Yoga Foundation');
      expect(YogaCatalog.flows[1].title, 'Intermediate Yoga Flow');
      expect(YogaCatalog.flows[2].title, 'Advanced Asana Mastery');
    });

    test('Basic Yoga (Beginner) contains exactly 15 poses in user-specified order', () {
      final beginner = YogaCatalog.flows[0];
      const expectedBeginner15 = [
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
      ];

      expect(beginner.exerciseIds, expectedBeginner15);
    });

    test('Intermediate Yoga contains exactly 15 poses in user-specified order', () {
      final intermediate = YogaCatalog.flows[1];
      const expectedIntermediate15 = [
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
      ];

      expect(intermediate.exerciseIds, expectedIntermediate15);
    });

    test('Advanced Yoga contains exactly 15 poses in user-specified order with safety warnings', () {
      final advanced = YogaCatalog.flows[2];
      const expectedAdvanced15 = [
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
      ];

      expect(advanced.exerciseIds, expectedAdvanced15);
      expect(advanced.cautions.any((c) => c.toLowerCase().contains('safety')), isTrue);
      expect(advanced.modifications.isNotEmpty, isTrue);
    });

    test('each flow contains guidance, duration, and valid YouTube video links', () {
      for (final flow in YogaCatalog.flows) {
        expect(flow.title.isNotEmpty, isTrue);
        expect(flow.durationMinutes, greaterThan(0));
        expect(flow.difficulty.isNotEmpty, isTrue);
        expect(flow.description.isNotEmpty, isTrue);
        expect(flow.breathingGuidance.isNotEmpty, isTrue);
        expect(flow.modifications.isNotEmpty, isTrue);
        expect(flow.cautions.isNotEmpty, isTrue);
        expect(flow.exerciseIds.length, 15);

        if (flow.videoUrl != null) {
          expect(
            flow.videoUrl!.startsWith('https://www.youtube.com/') ||
                flow.videoUrl!.startsWith('https://youtu.be/'),
            isTrue,
            reason: '${flow.title} videoUrl must be a valid YouTube URL',
          );
        }
      }
    });

    test('converts flow to a playable WorkoutPlan', () {
      for (final flow in YogaCatalog.flows) {
        final plan = flow.toWorkoutPlan();
        expect(plan.id, flow.id);
        expect(plan.title, flow.title);
        expect(plan.days.length, 1);
        expect(plan.days.first.id, '${flow.id}_day1');
        expect(plan.days.first.exercises.length, 15);
        expect(plan.days.first.exercises.first.durationSec, greaterThan(0));
      }
    });

    test('every flow exerciseId references an existing exercise and asset in exercises.json', () {
      final file = File('assets/data/exercises.json');
      expect(file.existsSync(), isTrue);

      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final exercisesList = jsonMap['exercises'] as List<dynamic>;
      final exerciseMap = {
        for (final e in exercisesList)
          (e as Map<String, dynamic>)['id'].toString(): e,
      };

      for (final flow in YogaCatalog.flows) {
        for (final exId in flow.exerciseIds) {
          expect(exerciseMap.containsKey(exId), isTrue,
              reason: 'Flow "${flow.title}" references unknown exercise "$exId"');

          final ex = exerciseMap[exId]!;
          final asset = ex['animation_asset'] as String?;
          expect(asset != null && asset.isNotEmpty, isTrue,
              reason: 'Exercise $exId missing animation_asset');
          expect(File(asset!).existsSync(), isTrue,
              reason: 'Asset $asset for exercise $exId does not exist on disk');
        }
      }
    });

    test('every yoga flow is registered in workout_plans.json and has resolvable days and 15 exercises', () {
      final plansFile = File('assets/data/workout_plans.json');
      expect(plansFile.existsSync(), isTrue);

      final plansMap = jsonDecode(plansFile.readAsStringSync()) as Map<String, dynamic>;
      final plansList = plansMap['plans'] as List<dynamic>;
      final planById = {
        for (final p in plansList)
          (p as Map<String, dynamic>)['id'].toString(): p,
      };

      for (final flow in YogaCatalog.flows) {
        expect(planById.containsKey(flow.id), isTrue,
            reason: 'Flow "${flow.id}" is missing from workout_plans.json');
        final planData = planById[flow.id]!;
        final days = planData['days'] as List<dynamic>;
        expect(days.isNotEmpty, isTrue);
        final day = days.first as Map<String, dynamic>;
        expect(day['id'], '${flow.id}_day1');
        final exercises = day['exercises'] as List<dynamic>;
        expect(exercises.length, 15);

        for (var i = 0; i < 15; i++) {
          final ex = exercises[i] as Map<String, dynamic>;
          expect(ex['exercise_id'], flow.exerciseIds[i],
              reason: 'Mismatch at index $i in plan ${flow.id}');
        }
      }
    });
  });
}
