import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
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
  _FakeCurrentProfileNotifier(this._profile);
  final Profile? _profile;

  @override
  Future<Profile?> build() async => _profile;
}

class _FakeChallengesNotifier extends ChallengesNotifier {
  _FakeChallengesNotifier(this._streak);
  final int _streak;

  @override
  Future<ChallengesState> build() async {
    return ChallengesState(
      completions: [],
      streak: StreakState(userId: 'u1', current: _streak),
      today: DateTime(2026, 11, 5),
    );
  }
}

void main() {
  setUp(() {
    resetHomeHeaderIntroState();
  });

  Widget buildHeaderTestHarness({
    Key? key,
    Profile? profile = const Profile(id: 'u1', name: 'Shivam Tiwari'),
    int streak = 7,
    int friendRequests = 0,
    int unviewedSnaps = 0,
    double? scrollProgress,
    bool forceCompact = false,
    bool reduceMotion = false,
    double textScaleFactor = 1.0,
    VoidCallback? onProfileNavigated,
  }) {
    final scrollNotifier =
        scrollProgress != null ? ValueNotifier<double>(scrollProgress) : null;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: reduceMotion,
                textScaler: TextScaler.linear(textScaleFactor),
              ),
              child: SingleChildScrollView(
                child: HomeHeaderBar(
                  scrollProgress: scrollNotifier,
                  forceCompact: forceCompact,
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) {
            onProfileNavigated?.call();
            return const Scaffold(body: Text('Profile Screen'));
          },
        ),
      ],
    );

    return ProviderScope(
      key: key,
      overrides: [
        currentProfileProvider
            .overrideWith(() => _FakeCurrentProfileNotifier(profile)),
        challengesProvider.overrideWith(() => _FakeChallengesNotifier(streak)),
        incomingRequestCountProvider.overrideWith((ref) => friendRequests),
        unviewedSnapsCountProvider.overrideWith((ref) => unviewedSnaps),
        dailyCompletionProgressProvider.overrideWithValue(
          const DailyCompletionProgress(
            completedCount: 3,
            totalCount: 6,
            tier: DailyCompletionTier.fourToFiveDone,
            stepsDone: true,
            caloriesDone: true,
            activeMinutesDone: true,
            workoutDone: false,
            waterDone: false,
            challengeDone: false,
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets(
      'Expanded state renders wordmark, tagline, first name, and streak badge',
      (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(streak: 5),
    );
    await tester.pumpAndSettle();

    expect(find.text('VYAYAMA'), findsOneWidget);
    expect(find.text('Every effort counts.'), findsOneWidget);
    expect(find.text('Shivam'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
  });

  testWidgets('Compact state collapses wordmark into 48dp circular avatar',
      (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(forceCompact: true),
    );
    await tester.pumpAndSettle();

    final profileBtn = find.byKey(const Key('home_profile_button'));
    expect(profileBtn, findsOneWidget);
    expect(tester.getSize(profileBtn).width, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(profileBtn).height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('Notification badge displays exact count when 3',
      (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(friendRequests: 2, unviewedSnaps: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Notification badge caps at 9+ when count exceeds 9',
      (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(friendRequests: 10, unviewedSnaps: 2),
    );
    await tester.pumpAndSettle();
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('Avatar fallback: initial when profile has name', (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(
        profile: const Profile(id: 'u1', name: 'Shivam Tiwari'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('Avatar fallback: person icon when profile is null',
      (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(profile: null),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets(
      'Intro skip: tapping header finishes animation and navigates on button tap',
      (tester) async {
    bool navigated = false;
    await tester.pumpWidget(
      buildHeaderTestHarness(
        onProfileNavigated: () => navigated = true,
      ),
    );

    // Middle of intro animation
    await tester.pump(const Duration(milliseconds: 300));

    // Tap profile button
    final profileBtn = find.byKey(const Key('home_profile_button'));
    await tester.tap(profileBtn);
    await tester.pumpAndSettle();

    expect(navigated, isTrue);
    expect(find.text('Profile Screen'), findsOneWidget);
  });

  testWidgets('Reduce motion jumps immediately to final state', (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(reduceMotion: true),
    );
    await tester.pump();

    // Final state is already present on first frame
    expect(find.text('VYAYAMA'), findsOneWidget);
    expect(find.text('Shivam'), findsOneWidget);
  });

  testWidgets('No overflow at 200% font scale', (tester) async {
    await tester.pumpWidget(
      buildHeaderTestHarness(
        textScaleFactor: 2.0,
        profile: const Profile(
          id: 'u1',
          name: 'Hubert Blaine Wolfeschlegelsteinhausenbergerdorff',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
