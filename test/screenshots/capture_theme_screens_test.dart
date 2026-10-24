import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/services/shared_prefs_provider.dart';

import 'package:fitbuddy/features/home/home_screen.dart';
import 'package:fitbuddy/features/workouts/screens/workouts_home_screen.dart';
import 'package:fitbuddy/features/workouts/data/workout_plan.dart';
import 'package:fitbuddy/features/workouts/data/exercise.dart';
import 'package:fitbuddy/features/workouts/providers.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/friends/screens/friends_list_screen.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/friends/data/friend.dart';
import 'package:fitbuddy/features/snaps/providers.dart';
import 'package:fitbuddy/features/profile/screens/profile_screen.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/schedule/clock_providers.dart';
import 'package:fitbuddy/features/nutrition/presentation/nutrition_screen.dart';

class _MockPlansNotifier extends MyPlansNotifier {
  _MockPlansNotifier(this._plans);
  final List<WorkoutPlan> _plans;
  @override
  Future<List<WorkoutPlan>> build() async => _plans;
}

class _MockProfileNotifier extends CurrentProfileNotifier {
  @override
  Future<Profile?> build() async => const Profile(
        id: 'u1',
        name: 'Alex Rivera',
        age: 26,
        gender: 'male',
        weightKg: 75.0,
        heightCm: 180.0,
        goal: 'stay_fit',
        fitnessLevel: 'intermediate',
        username: 'alex_fit',
        onboardingCompleted: true,
      );
}

class _MockConditionsNotifier extends SelectedConditionsNotifier {
  @override
  Future<List<String>> build() async => [];
}

const artifactDir =
    r'C:\Users\DELL\.gemini\antigravity-ide\brain\b48c3fcf-b24b-46e9-bee2-7f65229cbc7b';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final samplePlan = WorkoutPlan(
    id: 'plan_1',
    title: 'Full Body Starter',
    goal: 'fitness',
    level: 'beginner',
    isSystem: true,
    days: [
      PlanDay(
        id: 'd1',
        dayNumber: 1,
        name: 'Day 1: Full Body',
        exercises: const [
          PlanExercise(id: 'pe1', exerciseId: 'squat', sets: 3, reps: 10, restSec: 60),
        ],
      ),
    ],
  );

  final sampleExercise = const Exercise(
    id: 'squat',
    name: 'Squat',
    muscleGroup: 'legs',
    equipment: 'none',
    instructions: ['Stand with feet shoulder-width apart.'],
    commonMistakes: [],
    contraindications: [],
    met: 5.0,
  );

  final sampleFriend = const FriendWithStreak(
    user: FriendUser(
      id: 'u2',
      username: 'sarah_c',
      name: 'Sarah Chen',
    ),
  );

  List<Override> getOverrides(SharedPreferences prefs) => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentProfileProvider.overrideWith(() => _MockProfileNotifier()),
        defaultPlanProvider.overrideWith((ref) => Future.value(samplePlan)),
        myPlansProvider.overrideWith(() => _MockPlansNotifier([samplePlan])),
        systemPlansProvider.overrideWith((ref) => Future.value([samplePlan])),
        exerciseLibraryProvider.overrideWith((ref) => Future.value([sampleExercise])),
        selectedConditionTagsProvider.overrideWith((ref) => <String>[]),
        selectedConditionKeysProvider.overrideWith(() => _MockConditionsNotifier()),
        friendsWithStreakProvider.overrideWith((ref) => Future.value([sampleFriend])),
        incomingRequestCountProvider.overrideWith((ref) => 1),
        unviewedSnapsCountProvider.overrideWith((ref) => 2),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 24, 12, 0)),
        nowProvider.overrideWith((ref) => Stream.value(DateTime(2026, 10, 24, 12, 0))),
      ];

  Future<void> captureScreen({
    required WidgetTester tester,
    required Widget widget,
    required ThemeData theme,
    required String fileName,
    required SharedPreferences prefs,
  }) async {
    final repaintKey = GlobalKey();
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: getOverrides(prefs),
        child: MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: repaintKey,
            child: widget,
          ),
        ),
      ),
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final folder = fileName.startsWith('before')
          ? 'before'
          : fileName.startsWith('step_b')
              ? 'step_b'
              : 'after';
      final repoFile = File('test/screenshots/$folder/$fileName');
      await repoFile.parent.create(recursive: true);
      await repoFile.writeAsBytes(bytes);

      final artFile = File('$artifactDir/$fileName');
      await artFile.parent.create(recursive: true);
      await artFile.writeAsBytes(bytes);
    });

    // Drain entrance timers
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('Capture 10 baseline & step_b screens in light and dark mode', (WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final screens = <String, Widget>{
      'home': const HomeScreen(),
      'workouts': const WorkoutsHomeScreen(),
      'friends': const FriendsListScreen(),
      'profile': const ProfileScreen(),
      'nutrition': const NutritionScreen(),
    };

    for (final entry in screens.entries) {
      final name = entry.key;
      final widget = entry.value;

      // Light mode
      await captureScreen(
        tester: tester,
        widget: widget,
        theme: AppTheme.light(useGoogleFonts: false),
        fileName: 'step_b_${name}_light.png',
        prefs: prefs,
      );

      // Dark mode
      await captureScreen(
        tester: tester,
        widget: widget,
        theme: AppTheme.dark(useGoogleFonts: false),
        fileName: 'step_b_${name}_dark.png',
        prefs: prefs,
      );
    }

    expect(File('$artifactDir/step_b_home_light.png').existsSync(), isTrue);
    expect(File('$artifactDir/step_b_nutrition_dark.png').existsSync(), isTrue);
  });
}
