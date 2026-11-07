import 'package:fitbuddy/features/health_profile/presentation/widgets/wellness_app_bar.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/calorie_target_card.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/eat_limit_card.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/macro_card.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/meal_suggestions_section.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/water_tracker_card.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/core/widgets/glow_background.dart';
import 'package:fitbuddy/core/widgets/staggered_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Nutrition: calorie range, macros, water, eat/limit lists and meal ideas.
class NutritionScreen extends ConsumerWidget {
  /// Creates the screen.
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Let GlowBackground show through
      appBar: const WellnessAppBar(title: 'Nutrition'),
      body: GlowBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref
                ..invalidate(dietTipsProvider)
                ..invalidate(mealsProvider)
                ..invalidate(waterProvider)
                ..invalidate(selectedConditionKeysProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                StaggeredEntrance(
                  children: [
                    const CalorieTargetCard(),
                    const SizedBox(height: 16),
                    const MacroCard(),
                    const SizedBox(height: 16),
                    const WaterTrackerCard(),
                    const SizedBox(height: 16),
                    const EatLimitCard(),
                    const SizedBox(height: 24),
                    const MealSuggestionsSection(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(
                        'General wellness information, not medical advice. Consult a doctor or registered dietitian before starting a new diet program.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
