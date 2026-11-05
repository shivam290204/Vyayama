import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/screens/profile_screen.dart';

class _FakeCurrentProfileNotifier extends CurrentProfileNotifier {
  _FakeCurrentProfileNotifier(this._profile);
  final Profile? _profile;

  @override
  Future<Profile?> build() async => _profile;
}

void main() {
  testWidgets('ProfileScreen renders back button and navigates to dashboard/home', (tester) async {
    String? currentRoute;
    final testRouter = GoRouter(
      initialLocation: AppRoutes.profile,
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) {
            currentRoute = AppRoutes.home;
            return const Scaffold(body: Text('Dashboard Home'));
          },
        ),
      ],
    );

    const testProfile = Profile(
      id: 'u1',
      name: 'Shivam Tiwari',
      username: 'shivam290204',
      fitnessLevel: 'Beginner',
      goal: 'Stay fit',
      age: 22,
      gender: 'Male',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            () => _FakeCurrentProfileNotifier(testProfile),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: testRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final backBtn = find.byKey(const Key('profile_back_button'));
    expect(backBtn, findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(backBtn);
    await tester.pumpAndSettle();

    expect(currentRoute, equals(AppRoutes.home));
    expect(find.text('Dashboard Home'), findsOneWidget);
  });
}

