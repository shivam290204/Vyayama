import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';

class NameStep extends ConsumerStatefulWidget {
  const NameStep({super.key});

  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(onboardingProvider).name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      title: "What's your name?",
      subtitle: 'This is how your buddy will greet you.',
      child: TextFormField(
        controller: _controller,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.givenName],
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: ProfileValidators.name,
        onChanged: ref.read(onboardingProvider.notifier).setName,
        decoration: const InputDecoration(
          labelText: 'Name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
    );
  }
}
