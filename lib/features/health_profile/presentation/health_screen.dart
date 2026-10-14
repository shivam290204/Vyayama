import 'package:fitbuddy/core/widgets/animated_section_header.dart';
import 'package:fitbuddy/core/widgets/glow_background.dart';
import 'package:fitbuddy/core/widgets/staggered_entrance.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/conditions_section.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/health_hero_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/meal_reminders_section.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medical_disclaimer_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicine_edit_sheet.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicines_section.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Health profile: conditions, medicine reminders and meal reminders.
class HealthScreen extends ConsumerWidget {
  /// Creates the screen.
  const HealthScreen({super.key});

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
                ..invalidate(conditionRulesProvider)
                ..invalidate(selectedConditionKeysProvider)
                ..invalidate(medicinesProvider)
                ..invalidate(mealRemindersProvider);
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
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                        title: Text(
                          'Health Profile',
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
                              HealthHeroCard(),
                              SizedBox(height: 20),
                              MedicalDisclaimerCard(),
                              SizedBox(height: 24),
                              AnimatedSectionHeader(
                                title: 'Health conditions',
                                subtitle:
                                    'Pick anything that applies so we can suggest gentler exercise options.',
                                icon: Icons.health_and_safety_rounded,
                                delay: Duration(milliseconds: 150),
                              ),
                              ConditionsSection(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Medicine reminders',
                                subtitle:
                                    'Reminders only. We never suggest doses or give medical advice.',
                                icon: Icons.medication_rounded,
                                delay: const Duration(milliseconds: 300),
                                trailing: Builder(
                                  builder: (ctx) => FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(80, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    onPressed: () => showMedicineEditSheet(ctx),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add'),
                                  ),
                                ),
                              ),
                              MedicinesSection(),
                              SizedBox(height: 32),
                              AnimatedSectionHeader(
                                title: 'Meal reminders',
                                subtitle:
                                    'Tap a meal to change its time. Reminders repeat every day.',
                                icon: Icons.restaurant_rounded,
                                delay: Duration(milliseconds: 450),
                              ),
                              MealRemindersSection(),
                              SizedBox(height: 24),
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
