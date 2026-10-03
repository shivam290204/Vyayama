import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/auth/providers.dart';
import 'package:fitbuddy/features/onboarding/onboarding_step.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Raw answers collected during onboarding (text kept as typed).
@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.name = '',
    this.ageText = '',
    this.gender,
    this.weightText = '',
    this.heightCmText = '',
    this.heightFtText = '',
    this.heightInText = '',
    this.goal,
    this.fitnessLevel = 'beginner',
    this.wakeTime,
    this.sleepTime,
    this.workStart,
    this.workEnd,
  });

  final String name;
  final String ageText;
  final String? gender;
  final String weightText;
  final String heightCmText;
  final String heightFtText;
  final String heightInText;
  final String? goal;
  final String fitnessLevel;
  final TimeOfDay? wakeTime;
  final TimeOfDay? sleepTime;
  final TimeOfDay? workStart;
  final TimeOfDay? workEnd;

  int? get age => int.tryParse(ageText.trim());

  /// Under 18: weight-loss goals are hidden (spec Section 12).
  bool get isMinor => age != null && age! < 18;

  bool get hasSchedule =>
      wakeTime != null ||
      sleepTime != null ||
      workStart != null ||
      workEnd != null;

  OnboardingDraft copyWith({
    String? name,
    String? ageText,
    String? gender,
    String? weightText,
    String? heightCmText,
    String? heightFtText,
    String? heightInText,
    String? goal,
    bool clearGoal = false,
    String? fitnessLevel,
    TimeOfDay? wakeTime,
    TimeOfDay? sleepTime,
    TimeOfDay? workStart,
    TimeOfDay? workEnd,
    bool clearSchedule = false,
  }) {
    return OnboardingDraft(
      name: name ?? this.name,
      ageText: ageText ?? this.ageText,
      gender: gender ?? this.gender,
      weightText: weightText ?? this.weightText,
      heightCmText: heightCmText ?? this.heightCmText,
      heightFtText: heightFtText ?? this.heightFtText,
      heightInText: heightInText ?? this.heightInText,
      goal: clearGoal ? null : (goal ?? this.goal),
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      wakeTime: clearSchedule ? null : (wakeTime ?? this.wakeTime),
      sleepTime: clearSchedule ? null : (sleepTime ?? this.sleepTime),
      workStart: clearSchedule ? null : (workStart ?? this.workStart),
      workEnd: clearSchedule ? null : (workEnd ?? this.workEnd),
    );
  }

  /// Whether the answers for [step] are complete and valid.
  bool isValid(OnboardingStep step, UnitSystem unit) {
    return switch (step) {
      OnboardingStep.welcome => true,
      OnboardingStep.name => ProfileValidators.name(name) == null,
      OnboardingStep.age => ProfileValidators.age(ageText) == null,
      OnboardingStep.gender => gender != null,
      OnboardingStep.body =>
        ProfileValidators.weight(weightText, unit) == null &&
            ProfileValidators.height(
                  unit: unit,
                  cm: heightCmText,
                  ft: heightFtText,
                  inch: heightInText,
                ) ==
                null,
      OnboardingStep.goal => goal != null && !(isMinor && goal == 'lose'),
      OnboardingStep.level => true,
      OnboardingStep.schedule => true,
    };
  }
}

class OnboardingNotifier extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() {
    // Rebuild (reset) when a different user signs in.
    ref.watch(authStateProvider.select((auth) => auth.valueOrNull?.id));
    final user = ref.read(authStateProvider).valueOrNull;
    return OnboardingDraft(name: user?.displayName ?? '');
  }

  void setName(String value) => state = state.copyWith(name: value);

  void setAgeText(String value) {
    final next = state.copyWith(ageText: value);
    // Weight-loss goals are not offered to under-18s.
    state = (next.isMinor && next.goal == 'lose')
        ? next.copyWith(clearGoal: true)
        : next;
  }

  void setGender(String value) => state = state.copyWith(gender: value);
  void setWeightText(String value) => state = state.copyWith(weightText: value);
  void setHeightCmText(String value) => state = state.copyWith(heightCmText: value);
  void setHeightFtText(String value) => state = state.copyWith(heightFtText: value);
  void setHeightInText(String value) => state = state.copyWith(heightInText: value);
  void setGoal(String value) => state = state.copyWith(goal: value);
  void setLevel(String value) => state = state.copyWith(fitnessLevel: value);

  void setSchedule({
    TimeOfDay? wake,
    TimeOfDay? sleep,
    TimeOfDay? workStart,
    TimeOfDay? workEnd,
  }) {
    state = state.copyWith(
      wakeTime: wake,
      sleepTime: sleep,
      workStart: workStart,
      workEnd: workEnd,
    );
  }

  void clearSchedule() => state = state.copyWith(clearSchedule: true);

  /// Switches units and converts whatever the user already typed.
  void changeUnit(UnitSystem to) {
    final from = ref.read(unitSystemProvider);
    if (from == to) return;
    final d = state;
    final kg = ProfileValidators.weightKg(d.weightText, from);
    final cm = ProfileValidators.heightCm(
      unit: from,
      cm: d.heightCmText,
      ft: d.heightFtText,
      inch: d.heightInText,
    );
    final heights = cm == null ? null : ProfileValidators.heightTexts(cm, to);

    ref.read(unitSystemProvider.notifier).setSystem(to);
    state = d.copyWith(
      weightText: kg == null ? '' : ProfileValidators.weightText(kg, to),
      heightCmText: heights?.cm ?? '',
      heightFtText: heights?.ft ?? '',
      heightInText: heights?.inch ?? '',
    );
  }

  /// Saves the profile and marks onboarding as completed.
  /// The router redirect then moves the user into the app.
  Future<void> submit() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) throw StateError('Not signed in.');

    final unit = ref.read(unitSystemProvider);
    final d = state;
    final existing =
        ref.read(currentProfileProvider).valueOrNull ?? Profile(id: user.id);

    final profile = existing.copyWith(
      name: d.name.trim(),
      age: d.age,
      gender: d.gender,
      weightKg: ProfileValidators.weightKg(d.weightText, unit),
      heightCm: ProfileValidators.heightCm(
        unit: unit,
        cm: d.heightCmText,
        ft: d.heightFtText,
        inch: d.heightInText,
      ),
      goal: d.goal,
      fitnessLevel: d.fitnessLevel,
      wakeTime: d.wakeTime,
      sleepTime: d.sleepTime,
      workStart: d.workStart,
      workEnd: d.workEnd,
      onboardingCompleted: true,
    );
    await ref.read(currentProfileProvider.notifier).save(profile);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingDraft>(
  OnboardingNotifier.new,
);
