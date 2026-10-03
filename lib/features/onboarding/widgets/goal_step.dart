import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/option_card.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';

class GoalStep extends ConsumerWidget {
  const GoalStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(onboardingProvider.select((d) => d.goal));
    final isMinor = ref.watch(onboardingProvider.select((d) => d.isMinor));
    final notifier = ref.read(onboardingProvider.notifier);

    Widget card(String value, IconData icon, String title, String subtitle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: OptionCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          selected: goal == value,
          onTap: () => notifier.setGoal(value),
        ),
      );
    }

    return StepScaffold(
      title: "What's your goal?",
      subtitle: 'You can change this any time.',
      child: Column(
        children: [
          if (!isMinor)
            card(
              'lose',
              Icons.trending_down_rounded,
              'Lose weight',
              'Build healthy habits, step by step',
            ),
          card(
            'gain',
            Icons.trending_up_rounded,
            'Gain weight',
            'Build strength and eat well',
          ),
          card(
            'maintain',
            Icons.trending_flat_rounded,
            'Stay fit',
            'Keep moving and feel great',
          ),
        ],
      ),
    );
  }
}
