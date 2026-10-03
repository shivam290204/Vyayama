import 'package:fitbuddy/features/health_profile/presentation/widgets/medical_disclaimer_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/wellness_app_bar.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/alarm_guidance_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/reminder_toggles_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_foods_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_plan_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/wind_down_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/work_schedule_card.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sleep plan, reminders, wind-down checklist and alarm guidance.
class SleepScreen extends ConsumerWidget {
  /// Creates the screen.
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const WellnessAppBar(title: 'Sleep & alarm'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(sleepSettingsProvider)
              ..invalidate(dietTipsProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const <Widget>[
              WorkScheduleCard(),
              SizedBox(height: 16),
              SleepPlanCard(),
              SizedBox(height: 16),
              ReminderTogglesCard(),
              SizedBox(height: 16),
              AlarmGuidanceCard(),
              SizedBox(height: 16),
              WindDownCard(),
              SizedBox(height: 16),
              SleepFoodsCard(),
              SizedBox(height: 16),
              MedicalDisclaimerCard(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
