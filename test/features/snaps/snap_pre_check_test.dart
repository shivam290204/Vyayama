import 'dart:typed_data';

import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/snaps/data/mock_snap_repository.dart';
import 'package:fitbuddy/features/snaps/data/snap.dart';
import 'package:fitbuddy/features/snaps/data/snap_verification_service.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/snaps/screens/snap_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSnapPreCheck implements SnapPreCheck {
  FakeSnapPreCheck(this.result);

  PreCheckResult result;

  @override
  Future<PreCheckResult> check(String imagePath) async => result;
}

class FakeCapturedPhotoNotifier extends CapturedPhotoNotifier {
  FakeCapturedPhotoNotifier(this._initial);
  final CapturedPhoto? _initial;
  @override
  CapturedPhoto? build() => _initial;
}

class ImmediateSnapVerificationService implements SnapVerificationService {
  @override
  Future<VerificationResult> verify(String snapId) async =>
      VerificationResult.verified(activity: 'running', confidence: 0.95);

  @override
  Future<VerificationResult> appeal(String snapId) async =>
      VerificationResult.appealed(activity: 'running');
}

void main() {
  group('3-Tier PreCheckOutcome & Result Properties', () {
    test('supports likelyExercise, unlikely, and unsure outcomes', () {
      const outcomes = PreCheckOutcome.values;
      expect(outcomes, contains(PreCheckOutcome.likelyExercise));
      expect(outcomes, contains(PreCheckOutcome.unlikely));
      expect(outcomes, contains(PreCheckOutcome.unsure));
      expect(outcomes.length, 3);
    });

    test('backward compatibility aliases remain functional', () {
      expect(PreCheckOutcome.looksLikeExercise, PreCheckOutcome.likelyExercise);
      expect(PreCheckOutcome.noExerciseFound, PreCheckOutcome.unlikely);
      expect(PreCheckOutcome.unknown, PreCheckOutcome.unsure);
    });

    test('PreCheckResult helper getters accurately reflect outcome', () {
      const likely = PreCheckResult(PreCheckOutcome.likelyExercise, topLabel: 'Dumbbell');
      expect(likely.isLikelyExercise, isTrue);
      expect(likely.isUnlikely, isFalse);
      expect(likely.isUnsure, isFalse);

      const unlikely = PreCheckResult(PreCheckOutcome.unlikely, topLabel: 'Pizza');
      expect(unlikely.isLikelyExercise, isFalse);
      expect(unlikely.isUnlikely, isTrue);
      expect(unlikely.isUnsure, isFalse);

      const unsure = PreCheckResult(PreCheckOutcome.unsure, topLabel: 'Table');
      expect(unsure.isLikelyExercise, isFalse);
      expect(unsure.isUnlikely, isFalse);
      expect(unsure.isUnsure, isTrue);
    });
  });

  group('MlKitSnapPreCheck Label Evaluation Rules', () {
    test('identifies exercise-related labels as likelyExercise', () {
      final positiveSets = [
        ['Dumbbell', 'Arm'],
        ['Running shoe', 'Footwear'],
        ['Yoga mat', 'Floor'],
        ['Gym', 'Indoor'],
        ['Bicycle', 'Road'],
        ['Marathon runner', 'Person'],
        ['Treadmill', 'Machine'],
        ['Kettlebell', 'Weight'],
      ];

      for (final labels in positiveSets) {
        final result = MlKitSnapPreCheck.evaluateLabels(labels);
        expect(result.outcome, PreCheckOutcome.likelyExercise,
            reason: 'Labels $labels should be classified as likelyExercise');
        expect(result.topLabel, isNotNull);
      }
    });

    test('identifies non-exercise labels as unlikely', () {
      final negativeSets = [
        ['Pizza', 'Food', 'Dish'],
        ['Cat', 'Mammal', 'Pet'],
        ['Laptop', 'Computer keyboard', 'Desk'],
        ['Bed', 'Pillow', 'Bedroom'],
        ['Screenshot', 'Font', 'Text'],
        ['Automobile', 'Car', 'Vehicle'],
      ];

      for (final labels in negativeSets) {
        final result = MlKitSnapPreCheck.evaluateLabels(labels);
        expect(result.outcome, PreCheckOutcome.unlikely,
            reason: 'Labels $labels should be classified as unlikely');
        expect(result.topLabel, isNotNull);
      }
    });

    test('defaults neutral labels or empty lists to unsure', () {
      final neutralSets = [
        <String>[],
        ['Tree', 'Sky'],
        ['Building', 'Skyline'],
        ['Window', 'Wall'],
        ['Plant', 'Flower'],
      ];

      for (final labels in neutralSets) {
        final result = MlKitSnapPreCheck.evaluateLabels(labels);
        expect(result.outcome, PreCheckOutcome.unsure,
            reason: 'Labels $labels should be classified as unsure');
      }
    });

    test('allow list takes precedence over deny hints', () {
      // E.g., user is running and passes a food stand
      final mixedLabels = ['Running shoe', 'Fast food', 'Sidewalk'];
      final result = MlKitSnapPreCheck.evaluateLabels(mixedLabels);
      expect(result.outcome, PreCheckOutcome.likelyExercise);
      expect(result.topLabel, 'Running shoe');
    });
  });

  group('SnapPreviewScreen Pre-Check UI Behavior', () {
    Widget buildPreviewScreen({
      required PreCheckResult preCheckResult,
      required CapturedPhoto photo,
    }) {
      DateTime clock() => DateTime.utc(2026, 10, 25, 12, 0);
      final repo = MockSnapRepository(currentUserId: 'user-1', clock: clock);

      return ProviderScope(
        overrides: [
          capturedPhotoProvider.overrideWith(() => FakeCapturedPhotoNotifier(photo)),
          snapPreCheckProvider.overrideWithValue(FakeSnapPreCheck(preCheckResult)),
          snapRepositoryProvider.overrideWithValue(repo),
          friendsProvider.overrideWith((ref) async => [
                const FriendUser(
                  id: 'friend-1',
                  name: 'Priya',
                  username: 'priya_fit',
                  avatarUrl: null,
                ),
              ]),
          friendsWithStreakProvider.overrideWith((ref) async => []),
          snapVerificationServiceProvider.overrideWithValue(ImmediateSnapVerificationService()),
        ],
        child: const MaterialApp(
          home: SnapPreviewScreen(toFriendId: 'friend-1'),
        ),
      );
    }

    final validPng = Uint8List.fromList(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137,
      0, 0, 0, 11, 73, 68, 65, 84, 120, 156, 99, 96, 0, 0, 0, 2,
      0, 1, 244, 113, 100, 4, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ]);

    testWidgets('never blocks on unsure outcome: proceeds without dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final photo = CapturedPhoto(
        path: '/tmp/test_photo.jpg',
        bytes: validPng,
      );

      await tester.pumpWidget(buildPreviewScreen(
        preCheckResult: const PreCheckResult(PreCheckOutcome.unsure, topLabel: 'Sky'),
        photo: photo,
      ));
      await tester.pumpAndSettle();

      // Select an activity chip first to enable send
      await tester.tap(find.text('Running'));
      await tester.pumpAndSettle();

      // Tap Send button
      final sendButton = find.widgetWithText(FilledButton, 'Send');
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Must NOT display "Try again?" warning dialog
      expect(find.text('Try again?'), findsNothing);
    });

    testWidgets('proceeds without dialog on likelyExercise outcome', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final photo = CapturedPhoto(
        path: '/tmp/test_photo.jpg',
        bytes: validPng,
      );

      await tester.pumpWidget(buildPreviewScreen(
        preCheckResult: const PreCheckResult(PreCheckOutcome.likelyExercise, topLabel: 'Dumbbell'),
        photo: photo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Workout'));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(FilledButton, 'Send');
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      expect(find.text('Try again?'), findsNothing);
    });

    testWidgets('shows warning dialog ONLY on unlikely outcome, allows Send anyway', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final photo = CapturedPhoto(
        path: '/tmp/test_photo.jpg',
        bytes: validPng,
      );

      await tester.pumpWidget(buildPreviewScreen(
        preCheckResult: const PreCheckResult(PreCheckOutcome.unlikely, topLabel: 'Pizza'),
        photo: photo,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gym'));
      await tester.pumpAndSettle();

      final sendButton = find.widgetWithText(FilledButton, 'Send');
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Warning dialog MUST be shown
      expect(find.text('Try again?'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Send anyway'), findsOneWidget);

      // User taps "Send anyway" -> dialog dismisses and send continues
      await tester.tap(find.text('Send anyway'));
      await tester.pumpAndSettle();

      expect(find.text('Try again?'), findsNothing);
    });
  });
}
