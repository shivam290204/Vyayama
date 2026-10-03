import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/option_card.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';

class LevelStep extends ConsumerWidget {
  const LevelStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(onboardingProvider.select((d) => d.fitnessLevel));
    final notifier = ref.read(onboardingProvider.notifier);

    return StepScaffold(
      title: 'Your fitness level',
      subtitle: 'Be honest, there is no wrong answer.',
      child: Column(
        children: [
          OptionCard(
            icon: Icons.directions_walk_rounded,
            title: 'Beginner',
            subtitle: 'New to exercise or getting back into it',
            selected: level == 'beginner',
            onTap: () => notifier.setLevel('beginner'),
          ),
          const SizedBox(height: AppSpacing.md),
          OptionCard(
            icon: Icons.directions_run_rounded,
            title: 'Intermediate',
            subtitle: 'I work out fairly regularly',
            selected: level == 'intermediate',
            onTap: () => notifier.setLevel('intermediate'),
          ),
        ],
      ),
    );
  }
}
