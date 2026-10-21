import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/features/workouts/data/yoga_flow.dart';

void main() {
  group('YogaCatalog and YogaFlow', () {
    test('covers all 6 required yoga categories', () {
      final categoriesPresent = YogaCatalog.flows.map((f) => f.category).toSet();
      for (final cat in YogaCategory.values) {
        expect(categoriesPresent.contains(cat), isTrue,
            reason: 'Missing flow for category: ${cat.label}');
      }
    });

    test('each flow contains essential guidance and valid YouTube video links', () {
      for (final flow in YogaCatalog.flows) {
        expect(flow.title.isNotEmpty, isTrue);
        expect(flow.durationMinutes, greaterThan(0));
        expect(flow.difficulty.isNotEmpty, isTrue);
        expect(flow.description.isNotEmpty, isTrue);
        expect(flow.breathingGuidance.isNotEmpty, isTrue);
        expect(flow.modifications.isNotEmpty, isTrue);
        expect(flow.cautions.isNotEmpty, isTrue);
        expect(flow.exerciseIds.length, greaterThanOrEqualTo(3));

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
      final flow = YogaCatalog.flows.first;
      final plan = flow.toWorkoutPlan();

      expect(plan.id, flow.id);
      expect(plan.title, flow.title);
      expect(plan.days.length, 1);
      expect(plan.days.first.exercises.length, flow.exerciseIds.length);
      expect(plan.days.first.exercises.first.durationSec, greaterThan(0));
    });

    test('every flow exerciseId references an existing exercise in exercises.json', () {
      final file = File('assets/data/exercises.json');
      expect(file.existsSync(), isTrue);

      final jsonMap = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final exercisesList = jsonMap['exercises'] as List<dynamic>;
      final knownIds = exercisesList
          .map((e) => (e as Map<String, dynamic>)['id'].toString())
          .toSet();

      for (final flow in YogaCatalog.flows) {
        for (final exId in flow.exerciseIds) {
          expect(knownIds.contains(exId), isTrue,
              reason: 'Flow "${flow.title}" references unknown exercise "$exId"');
        }
      }
    });

    test('every yoga flow is registered in workout_plans.json and has resolvable days and exercises', () {
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
        expect(exercises.length, flow.exerciseIds.length);
      }
    });
  });
}
