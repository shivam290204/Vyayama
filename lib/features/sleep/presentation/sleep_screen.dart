import 'package:fitbuddy/core/widgets/animated_section_header.dart';
import 'package:fitbuddy/core/widgets/glow_background.dart';
import 'package:fitbuddy/core/widgets/staggered_entrance.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medical_disclaimer_card.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlowBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: scheme.primary,
            onRefresh: () async {
              ref
                ..invalidate(sleepSettingsProvider)
                ..invalidate(dietTipsProvider);
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // Collapsing App Bar
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 120,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 48, bottom: 16),
                        title: Text(
                          'Sleep & alarm',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          StaggeredEntrance(
                            children: [
                              AnimatedSectionHeader(
                                title: 'Your day',
                                subtitle: 'Set your work hours and goal.',
                                icon: Icons.schedule_rounded,
                                delay: Duration(milliseconds: 100),
                              ),
                              WorkScheduleCard(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Sleep plan',
                                subtitle: 'Your suggested bedtime and wake-up.',
                                icon: Icons.bedtime_rounded,
                                delay: Duration(milliseconds: 200),
                              ),
                              SleepPlanCard(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Reminders',
                                subtitle: 'Daily nudges for bedtime and wake-up.',
                                icon: Icons.alarm_rounded,
                                delay: Duration(milliseconds: 300),
                              ),
                              ReminderTogglesCard(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Alarm tips',
                                subtitle: 'How to use Vyayama alarms effectively.',
                                icon: Icons.lightbulb_rounded,
                                delay: Duration(milliseconds: 400),
                              ),
                              AlarmGuidanceCard(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Wind-down',
                                subtitle: 'Prepare your body for sleep.',
                                icon: Icons.spa_rounded,
                                delay: Duration(milliseconds: 500),
                              ),
                              WindDownCard(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Sleep foods',
                                subtitle: 'What to eat and avoid before bed.',
                                icon: Icons.restaurant_menu_rounded,
                                delay: Duration(milliseconds: 600),
                              ),
                              SleepFoodsCard(),
                              SizedBox(height: 32),
                              MedicalDisclaimerCard(),
                              SizedBox(height: 32),
                            ],
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
