import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/auth/widgets/button_spinner.dart';
import 'package:fitbuddy/features/onboarding/onboarding_step.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/age_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/body_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/gender_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/goal_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/level_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/name_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/schedule_step.dart';
import 'package:fitbuddy/features/onboarding/widgets/welcome_step.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Multi-step onboarding with a progress bar and back button.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<OnboardingStep> _steps = OnboardingStep.values;

  // Must match the order of [OnboardingStep].
  static const List<Widget> _pages = [
    WelcomeStep(),
    NameStep(),
    AgeStep(),
    GenderStep(),
    BodyStep(),
    GoalStep(),
    LevelStep(),
    ScheduleStep(),
  ];

  final PageController _controller = PageController();
  int _index = 0;
  bool _saving = false;

  bool get _isLast => _index == _steps.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _index = index);
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_index > 0 && !_saving) _goTo(_index - 1);
  }

  void _next() => _isLast ? _finish() : _goTo(_index + 1);

  Future<void> _finish({bool skipSchedule = false}) async {
    final notifier = ref.read(onboardingProvider.notifier);
    if (skipSchedule) notifier.clearSchedule();
    setState(() => _saving = true);
    try {
      await notifier.submit();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("We couldn't save your profile. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _primaryLabel {
    if (_index == 0) return "I understand, let's go";
    return _isLast ? 'Finish' : 'Continue';
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingProvider);
    final unit = ref.watch(unitSystemProvider);
    final canContinue = draft.isValid(_steps[_index], unit) && !_saving;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  0,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: _index > 0
                          ? IconButton(
                              tooltip: 'Back',
                              icon: const Icon(Icons.arrow_back_rounded),
                              onPressed: _saving ? null : _back,
                            )
                          : null,
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: (_index + 1) / _steps.length,
                          minHeight: 8,
                          semanticsLabel:
                              'Step ${_index + 1} of ${_steps.length}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _pages,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: canContinue ? _next : null,
                          child: _saving
                              ? const ButtonSpinner()
                              : Text(_primaryLabel),
                        ),
                        if (_isLast)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => _finish(skipSchedule: true),
                            child: const Text('Skip for now'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
