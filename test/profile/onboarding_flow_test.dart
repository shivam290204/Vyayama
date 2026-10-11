import 'package:fitbuddy/core/router/app_router.dart';
import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/auth/data/auth_repository.dart';
import 'package:fitbuddy/features/onboarding/onboarding_step.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Router AppRedirect Logic', () {
    const user = AuthUser(id: 'u-1', email: 'test@example.com');

    test('redirects unauthenticated user to /login', () {
      final dest = appRedirect(
        location: AppRoutes.home,
        auth: const AsyncData(null),
        profile: const AsyncData(null),
      );
      expect(dest, AppRoutes.login);
    });

    test('permits unauthenticated user on public routes', () {
      final dest = appRedirect(
        location: AppRoutes.login,
        auth: const AsyncData(null),
        profile: const AsyncData(null),
      );
      expect(dest, isNull);
    });

    test('redirects authenticated user with incomplete onboarding to /onboarding', () {
      const incompleteProfile = Profile(id: 'u-1', onboardingCompleted: false);
      final dest = appRedirect(
        location: AppRoutes.home,
        auth: const AsyncData(user),
        profile: const AsyncData(incompleteProfile),
      );
      expect(dest, AppRoutes.onboarding);
    });

    test('stays on /onboarding while completing steps', () {
      const incompleteProfile = Profile(id: 'u-1', onboardingCompleted: false);
      final dest = appRedirect(
        location: AppRoutes.onboarding,
        auth: const AsyncData(user),
        profile: const AsyncData(incompleteProfile),
      );
      expect(dest, isNull);
    });

    test('redirects completed onboarding to /home from entry routes', () {
      const completedProfile = Profile(id: 'u-1', onboardingCompleted: true);
      final dest = appRedirect(
        location: AppRoutes.onboarding,
        auth: const AsyncData(user),
        profile: const AsyncData(completedProfile),
      );
      expect(dest, AppRoutes.home);
    });

    test('allows navigation to internal routes when onboarding is complete', () {
      const completedProfile = Profile(id: 'u-1', onboardingCompleted: true);
      final dest = appRedirect(
        location: AppRoutes.workouts,
        auth: const AsyncData(user),
        profile: const AsyncData(completedProfile),
      );
      expect(dest, isNull);
    });
  });

  group('OnboardingDraft Validation', () {
    test('validates name step', () {
      var draft = const OnboardingDraft(name: '');
      expect(draft.isValid(OnboardingStep.name, UnitSystem.metric), false);

      draft = draft.copyWith(name: 'Shivam');
      expect(draft.isValid(OnboardingStep.name, UnitSystem.metric), true);
    });

    test('validates age step and flags minor', () {
      var draft = const OnboardingDraft(ageText: '10'); // below 13
      expect(draft.isValid(OnboardingStep.age, UnitSystem.metric), false);

      draft = draft.copyWith(ageText: '16'); // valid minor
      expect(draft.isValid(OnboardingStep.age, UnitSystem.metric), true);
      expect(draft.isMinor, true);

      // Minor cannot choose "lose" weight
      draft = draft.copyWith(goal: 'lose');
      expect(draft.isValid(OnboardingStep.goal, UnitSystem.metric), false);

      draft = draft.copyWith(goal: 'maintain');
      expect(draft.isValid(OnboardingStep.goal, UnitSystem.metric), true);
    });

    test('validates body step with metric units', () {
      const draft = OnboardingDraft(
        weightText: '72',
        heightCmText: '178',
      );
      expect(draft.isValid(OnboardingStep.body, UnitSystem.metric), true);
    });

    test('validates body step with imperial units', () {
      const draft = OnboardingDraft(
        weightText: '160',
        heightFtText: '5',
        heightInText: '10',
      );
      expect(draft.isValid(OnboardingStep.body, UnitSystem.imperial), true);
    });
  });
}
