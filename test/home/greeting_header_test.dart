import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/home/widgets/greeting_header.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';

class _FakeCurrentProfileNotifier extends CurrentProfileNotifier {
  _FakeCurrentProfileNotifier(this._profile);
  final Profile? _profile;

  @override
  Future<Profile?> build() async => _profile;
}

void main() {
  Widget buildGreetingHeaderHarness({
    Profile? profile = const Profile(id: 'u1', name: 'Shivam Tiwari'),
    GoRouter? router,
  }) {
    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: GreetingHeader(),
              ),
            ),
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const Scaffold(
                body: Text('Profile Screen'),
              ),
            ),
          ],
        );

    return ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith(
          () => _FakeCurrentProfileNotifier(profile),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: effectiveRouter,
      ),
    );
  }

  testWidgets('GreetingHeader renders brand elements and circular Profile button', (tester) async {
    await tester.pumpWidget(buildGreetingHeaderHarness());
    await tester.pumpAndSettle();

    expect(find.text('VYAYAMA'), findsOneWidget);
    expect(find.text('Every effort counts.'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byKey(const Key('home_profile_button')), findsOneWidget);
  });

  testWidgets('GreetingHeader renders greeting and date', (tester) async {
    await tester.pumpWidget(buildGreetingHeaderHarness());
    await tester.pumpAndSettle();

    // With profile name "Shivam Tiwari", greeting displays "..., Shivam!"
    expect(find.textContaining('Shivam!'), findsOneWidget);
  });

  testWidgets('Tapping circular Profile button navigates to AppRoutes.profile', (tester) async {
    String? navigatedRoute;
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: GreetingHeader(),
          ),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) {
            navigatedRoute = AppRoutes.profile;
            return const Scaffold(body: Text('Profile Screen'));
          },
        ),
      ],
    );

    await tester.pumpWidget(buildGreetingHeaderHarness(router: testRouter));
    await tester.pumpAndSettle();

    final profileBtn = find.byKey(const Key('home_profile_button'));
    expect(profileBtn, findsOneWidget);
    await tester.tap(profileBtn);
    await tester.pumpAndSettle();

    expect(navigatedRoute, equals(AppRoutes.profile));
    expect(find.text('Profile Screen'), findsOneWidget);
  });

  testWidgets('GreetingHeader falls back to default name when profile is null', (tester) async {
    await tester.pumpWidget(buildGreetingHeaderHarness(profile: null));
    await tester.pumpAndSettle();

    // Default fallback name in MascotMessagePicker is "friend"
    expect(find.textContaining('friend!'), findsOneWidget);
  });
}
