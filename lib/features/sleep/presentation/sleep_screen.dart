import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/widgets/animated_section_header.dart';
import 'package:fitbuddy/core/widgets/glow_background.dart';
import 'package:fitbuddy/core/widgets/staggered_entrance.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medical_disclaimer_card.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/alarm_guidance_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/reminder_toggles_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_foods_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_hero_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_plan_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/wind_down_card.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/work_schedule_card.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRoutes.home);
                          }
                        },
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
                            children: const [
                              // Hero Card with sleeping mascot
                              SleepHeroCard(),
                              SizedBox(height: 24),

                              AnimatedSectionHeader(
                                title: 'Sleep plan',
                                subtitle: 'Tap bedtime or wake up to customize.',
                                icon: Icons.bedtime_rounded,
                                delay: Duration(milliseconds: 100),
                              ),
                              SleepPlanCard(),
                              SizedBox(height: 32),

                              AnimatedSectionHeader(
                                title: 'Alarm & reminders',
                                subtitle: 'Set wake-up alarm sound, repeat days and wind-down.',
                                icon: Icons.alarm_rounded,
                                delay: Duration(milliseconds: 200),
                              ),
                              ReminderTogglesCard(),
                              SizedBox(height: 32),

                              AnimatedSectionHeader(
                                title: 'Work schedule & routine',
                                subtitle: 'Set work hours to optimize your sleep calculation.',
                                icon: Icons.schedule_rounded,
                                delay: Duration(milliseconds: 300),
                              ),
                              WorkScheduleCard(),
                              SizedBox(height: 32),

                              AnimatedSectionHeader(
                                title: 'Wind-down',
                                subtitle: 'Prepare your body for sleep.',
                                icon: Icons.spa_rounded,
                                delay: Duration(milliseconds: 400),
                              ),
                              WindDownCard(),
                              SizedBox(height: 32),

                              AnimatedSectionHeader(
                                title: 'Sleep foods',
                                subtitle: 'What to eat and avoid before bed.',
                                icon: Icons.restaurant_menu_rounded,
                                delay: Duration(milliseconds: 500),
                              ),
                              SleepFoodsCard(),
                              SizedBox(height: 32),

                              AnimatedSectionHeader(
                                title: 'Alarm tips',
                                subtitle: 'How to make sure alarms ring on time.',
                                icon: Icons.lightbulb_rounded,
                                delay: Duration(milliseconds: 600),
                              ),
                              AlarmGuidanceCard(),
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
