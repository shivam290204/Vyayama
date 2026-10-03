import 'package:fitbuddy/features/health_profile/presentation/widgets/conditions_section.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/meal_reminders_section.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medical_disclaimer_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicines_section.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/wellness_app_bar.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Health profile: conditions, medicine reminders and meal reminders.
class HealthScreen extends ConsumerWidget {
  /// Creates the screen.
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const WellnessAppBar(title: 'Health profile'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(conditionRulesProvider)
              ..invalidate(selectedConditionKeysProvider)
              ..invalidate(medicinesProvider)
              ..invalidate(mealRemindersProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const <Widget>[
              MedicalDisclaimerCard(),
              SizedBox(height: 24),
              ConditionsSection(),
              SizedBox(height: 32),
              MedicinesSection(),
              SizedBox(height: 32),
              MealRemindersSection(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
