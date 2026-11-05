import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/challenges/challenges_state.dart';
import 'package:fitbuddy/features/challenges/data/streak_state.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/friends/providers.dart';
import 'package:fitbuddy/features/home/providers/daily_completion_provider.dart';
import 'package:fitbuddy/features/home/widgets/greeting_header.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/snaps/providers.dart';

class _FakeCurrentProfileNotifier extends CurrentProfileNotifier {
  @override
  Future<Profile?> build() async => const Profile(
        id: 'u1',
        name: 'Shivam Tiwari',
        avatarUrl: null,
      );
}

class _FakeChallengesNotifier extends ChallengesNotifier {
  @override
  Future<ChallengesState> build() async {
    return ChallengesState(
      completions: [],
      streak: const StreakState(userId: 'u1', current: 7),
      today: DateTime(2026, 11, 5),
    );
  }
}

const artifactDir =
    r'C:\Users\DELL\.gemini\antigravity\brain\b48c3fcf-b24b-46e9-bee2-7f65229cbc7b\header_morph_filmstrip';

void main() {
  testWidgets('Capture header morph filmstrip (0%, 25%, 50%, 75%, 100%) in light & dark mode',
      (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final steps = [
      (0.0, true, '0pct_brand'),
      (0.0, false, 'rest_state'),
      (0.25, false, '25pct_compact'),
      (0.50, false, '50pct_compact'),
      (0.75, false, '75pct_compact'),
      (1.0, false, '100pct_compact'),
    ];

    final modes = [
      (Brightness.light, 'light'),
      (Brightness.dark, 'dark'),
    ];

    for (final (brightness, modeName) in modes) {
      final theme = brightness == Brightness.dark
          ? AppTheme.dark(useGoogleFonts: false)
          : AppTheme.light(useGoogleFonts: false);

      for (final (progress, isBrand, stepLabel) in steps) {
        resetHomeHeaderIntroState();
        final repaintKey = GlobalKey();
        final scrollNotifier = ValueNotifier<double>(progress);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentProfileProvider.overrideWith(_FakeCurrentProfileNotifier.new),
              challengesProvider.overrideWith(_FakeChallengesNotifier.new),
              incomingRequestCountProvider.overrideWith((ref) => 3),
              unviewedSnapsCountProvider.overrideWith((ref) => 2),
              dailyCompletionProgressProvider.overrideWithValue(
                const DailyCompletionProgress(
                  completedCount: 6,
                  totalCount: 6,
                  tier: DailyCompletionTier.everythingDone,
                  stepsDone: true,
                  caloriesDone: true,
                  activeMinutesDone: true,
                  workoutDone: true,
                  waterDone: true,
                  challengeDone: true,
                ),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: RepaintBoundary(
                      key: repaintKey,
                      child: HomeIdentityBar(
                        scrollProgress: scrollNotifier,
                        forceBrand: isBrand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.runAsync(() async {
          final boundary = repaintKey.currentContext!
              .findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          final bytes = byteData!.buffer.asUint8List();

          final fileName = 'identity_bar_${stepLabel}_$modeName.png';

          final outputDir = Directory('build/test_screenshots/filmstrip');
          final outputFile = File('${outputDir.path}/$fileName');
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(bytes);

          final artFile = File('$artifactDir/$fileName');
          await artFile.parent.create(recursive: true);
          await artFile.writeAsBytes(bytes);
        });
      }
    }
  });
}
