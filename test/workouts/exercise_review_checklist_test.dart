import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/widgets/unreviewed_form_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> exercises;
  late String checklistContent;

  setUpAll(() {
    final exercisesFile = File('assets/data/exercises.json');
    expect(exercisesFile.existsSync(), isTrue,
        reason: 'assets/data/exercises.json must exist');
    final raw = exercisesFile.readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    exercises = (json['exercises'] as List).cast<Map<String, dynamic>>();

    final checklistFile = File('REVIEW_CHECKLIST.md');
    expect(checklistFile.existsSync(), isTrue,
        reason: 'REVIEW_CHECKLIST.md must exist');
    checklistContent = checklistFile.readAsStringSync();
  });

  group('Exercise Review Checklist Enforcement', () {
    test('all 125 database exercises currently have unreviewed status', () {
      expect(exercises.length, 125);
      for (final ex in exercises) {
        final reviewedBy = ex['reviewed_by'];
        final reviewedAt = ex['reviewed_at'];
        expect(
          reviewedBy == null || (reviewedBy as String).trim().isEmpty,
          isTrue,
          reason: 'Exercise ${ex['id']} (${ex['name']}) must not have reviewed_by automatically set',
        );
        expect(
          reviewedAt == null || (reviewedAt as String).trim().isEmpty,
          isTrue,
          reason: 'Exercise ${ex['id']} (${ex['name']}) must not have reviewed_at automatically set',
        );
      }
    });

    test(
        'fails if any exercise has reviewed_by set without a matching entry in REVIEW_CHECKLIST.md',
        () {
      final unrecordedReviewed = <String>[];

      for (final ex in exercises) {
        final reviewedBy = (ex['reviewed_by'] as String?)?.trim();
        if (reviewedBy != null && reviewedBy.isNotEmpty) {
          final id = ex['id'].toString();
          final name = ex['name'].toString();
          final hasEntry = checklistContent.contains(id) || checklistContent.contains(name);
          if (!hasEntry) {
            unrecordedReviewed.add('$id ("$name") reviewed by "$reviewedBy"');
          }
        }
      }

      expect(
        unrecordedReviewed,
        isEmpty,
        reason:
            'Exercises with reviewed_by set must have a matching entry in REVIEW_CHECKLIST.md: ${unrecordedReviewed.join(", ")}',
      );
    });

    test('validation helper catches missing checklist entries for reviewed exercises', () {
      String? validateExerciseReview(Exercise ex, String checklist) {
        if (ex.reviewedBy != null && ex.reviewedBy!.trim().isNotEmpty) {
          final idMatch = checklist.contains(ex.id);
          final nameMatch = checklist.contains(ex.name);
          if (!idMatch && !nameMatch) {
            return 'Exercise ${ex.id} has reviewed_by set but is missing from REVIEW_CHECKLIST.md';
          }
        }
        return null;
      }

      // Exercise without reviewed_by passes
      final unreviewed = Exercise(
        id: 'ex_test_1',
        name: 'Test Movement',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: const [],
        commonMistakes: const [],
        contraindications: const [],
        met: 3.0,
      );
      expect(validateExerciseReview(unreviewed, checklistContent), isNull);

      // Exercise with reviewed_by but missing from checklist returns failure error
      final unauthorizedReviewed = Exercise(
        id: 'ex_unauthorized_123',
        name: 'Unauthorized Pose',
        muscleGroup: 'legs',
        equipment: 'none',
        instructions: const [],
        commonMistakes: const [],
        contraindications: const [],
        met: 3.0,
        reviewedBy: 'Random User',
      );
      final error = validateExerciseReview(unauthorizedReviewed, checklistContent);
      expect(error, isNotNull);
      expect(error, contains('missing from REVIEW_CHECKLIST.md'));
    });
  });

  group('UnreviewedFormNotice Widget Tests', () {
    testWidgets('renders calm unreviewed notice with correct text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreviewedFormNotice(),
          ),
        ),
      );

      expect(
        find.text(
          'Form guidance is general and has not yet been reviewed by a fitness professional.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('renders compact version properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UnreviewedFormNotice(compact: true),
          ),
        ),
      );

      expect(
        find.text(
          'Form guidance is general and has not yet been reviewed by a fitness professional.',
        ),
        findsOneWidget,
      );
    });
  });
}
