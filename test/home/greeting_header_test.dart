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

  Widget buildIdentityBarHarness({
    Key? key,
    Profile? profile = const Profile(id: 'u1', name: 'Shivam Tiwari'),
    int streak = 7,
    int friendRequests = 0,
    int unviewedSnaps = 0,
    double? scrollProgress,
    bool forceCompact = false,
    bool forceBrand = false,
    bool reduceMotion = false,
    double textScaleFactor = 1.0,
    VoidCallback? onProfileNavigated,
    VoidCallback? onRequestsNavigated,
    VoidCallback? onSnapsNavigated,
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
                child: HomeIdentityBar(
                  key: key,
                  scrollProgress: scrollNotifier,
                  forceCompact: forceCompact,
                  forceBrand: forceBrand,
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
        GoRoute(
          path: AppRoutes.friendsRequests,
          builder: (context, state) {
            onRequestsNavigated?.call();
            return const Scaffold(body: Text('Friends Requests Screen'));
          },
        ),
        GoRoute(
          path: AppRoutes.snapsInbox,
          builder: (context, state) {
            onSnapsNavigated?.call();
            return const Scaffold(body: Text('Snaps Inbox Screen'));
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
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('Brand state renders logo, VYAYAMA, and tagline', (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(forceBrand: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('VYAYAMA'), findsOneWidget);
    expect(find.text('Every effort counts.'), findsOneWidget);
  });

  testWidgets('Rest state renders avatar, greeting, date, streak chip, and bell',
      (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(streak: 5, friendRequests: 2),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Shivam!'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.byKey(const Key('home_bell_button')), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // Bell notification count
  });

  testWidgets('Compact state collapses middle greeting while retaining avatar and bell',
      (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(forceCompact: true, friendRequests: 1),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_profile_button')), findsOneWidget);
    expect(find.byKey(const Key('home_bell_button')), findsOneWidget);
    // Middle greeting and streak chip are hidden in compact state
    expect(find.textContaining('Shivam!'), findsNothing);
    expect(find.text('🔥'), findsNothing);
  });

  testWidgets('Intro skip: tapping header finishes animation and navigates on button tap',
      (tester) async {
    bool navigated = false;
    await tester.pumpWidget(
      buildIdentityBarHarness(
        onProfileNavigated: () => navigated = true,
      ),
    );

    // In middle of intro (brand state)
    await tester.pump(const Duration(milliseconds: 200));

    // Tap identity bar to skip intro
    await tester.tap(find.byType(HomeIdentityBar));
    await tester.pumpAndSettle();

    // Now in rest state, tap profile button
    final profileBtn = find.byKey(const Key('home_profile_button'));
    await tester.tap(profileBtn);
    await tester.pumpAndSettle();

    expect(navigated, isTrue);
    expect(find.text('Profile Screen'), findsOneWidget);
  });

  testWidgets('Notification bell navigates to friendsRequests when requests > 0',
      (tester) async {
    bool requestsNavigated = false;
    await tester.pumpWidget(
      buildIdentityBarHarness(
        friendRequests: 3,
        onRequestsNavigated: () => requestsNavigated = true,
      ),
    );
    await tester.pumpAndSettle();

    final bellBtn = find.byKey(const Key('home_bell_button'));
    await tester.tap(bellBtn);
    await tester.pumpAndSettle();

    expect(requestsNavigated, isTrue);
    expect(find.text('Friends Requests Screen'), findsOneWidget);
  });

  testWidgets('Notification bell navigates to snapsInbox when requests == 0 and snaps > 0',
      (tester) async {
    bool snapsNavigated = false;
    await tester.pumpWidget(
      buildIdentityBarHarness(
        friendRequests: 0,
        unviewedSnaps: 4,
        onSnapsNavigated: () => snapsNavigated = true,
      ),
    );
    await tester.pumpAndSettle();

    final bellBtn = find.byKey(const Key('home_bell_button'));
    await tester.tap(bellBtn);
    await tester.pumpAndSettle();

    expect(snapsNavigated, isTrue);
    expect(find.text('Snaps Inbox Screen'), findsOneWidget);
  });

  testWidgets('Notification badge caps at 9+ when count exceeds 9',
      (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(friendRequests: 10, unviewedSnaps: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('Avatar fallback: first initial when profile has name',
      (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(
        profile: const Profile(id: 'u1', name: 'Shivam Tiwari'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('Avatar fallback: person icon when profile is null',
      (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(profile: null),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
  });

  testWidgets('Reduce motion jumps immediately to final state', (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(reduceMotion: true),
    );
    await tester.pump();

    expect(find.textContaining('Shivam!'), findsOneWidget);
  });

  testWidgets('No overflow with long name at 200% font scale', (tester) async {
    await tester.pumpWidget(
      buildIdentityBarHarness(
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
