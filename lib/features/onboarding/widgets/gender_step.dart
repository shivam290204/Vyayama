import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/option_card.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';

class GenderStep extends ConsumerWidget {
  const GenderStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider.select((d) => d.gender));
    final notifier = ref.read(onboardingProvider.notifier);

    Widget card(String value, IconData icon, String title) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: OptionCard(
            icon: icon,
            title: title,
            selected: selected == value,
            onTap: () => notifier.setGender(value),
          ),
        );

    return StepScaffold(
      title: 'How do you identify?',
      subtitle: 'Used only to estimate calories more accurately.',
      child: Column(
        children: [
          card('male', Icons.male_rounded, 'Male'),
          card('female', Icons.female_rounded, 'Female'),
          card('other', Icons.transgender_rounded, 'Other or prefer not to say'),
        ],
      ),
    );
  }
}
