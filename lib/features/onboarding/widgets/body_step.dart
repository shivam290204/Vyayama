import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';
import 'package:fitbuddy/features/profile/widgets/measurement_fields.dart';
import 'package:fitbuddy/features/settings/providers.dart';

class BodyStep extends ConsumerWidget {
  const BodyStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final unit = ref.watch(unitSystemProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return StepScaffold(
      title: 'Your height and weight',
      subtitle: 'Pick the units you like. You can switch later in Settings.',
      child: MeasurementFields(
        unit: unit,
        weightText: draft.weightText,
        cmText: draft.heightCmText,
        ftText: draft.heightFtText,
        inText: draft.heightInText,
        onUnitChanged: notifier.changeUnit,
        onWeightChanged: notifier.setWeightText,
        onCmChanged: notifier.setHeightCmText,
        onFtChanged: notifier.setHeightFtText,
        onInChanged: notifier.setHeightInText,
      ),
    );
  }
}
