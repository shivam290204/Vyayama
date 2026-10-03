import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';

class AgeStep extends ConsumerStatefulWidget {
  const AgeStep({super.key});

  @override
  ConsumerState<AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends ConsumerState<AgeStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(onboardingProvider).ageText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMinor = ref.watch(onboardingProvider.select((d) => d.isMinor));

    return StepScaffold(
      title: 'How old are you?',
      subtitle: 'Ages ${ProfileValidators.minAge} to ${ProfileValidators.maxAge}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: ProfileValidators.age,
            onChanged: ref.read(onboardingProvider.notifier).setAgeText,
            decoration: const InputDecoration(
              labelText: 'Age',
              suffixText: 'years',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isMinor
                ? "Vyayama is designed for adults, so we'll keep your options "
                    'gentle and age-appropriate. Please use it with a parent or guardian.'
                : 'Vyayama is designed for adults 18 and over.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
