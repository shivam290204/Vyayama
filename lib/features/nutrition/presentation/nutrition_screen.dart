import 'package:fitbuddy/features/health_profile/presentation/widgets/medical_disclaimer_card.dart';
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
              children: const <Widget>[
                StaggeredEntrance(
                  children: [
                    MedicalDisclaimerCard(),
                    SizedBox(height: 16),
                    CalorieTargetCard(),
                    SizedBox(height: 16),
                    MacroCard(),
                    SizedBox(height: 16),
                    WaterTrackerCard(),
                    SizedBox(height: 16),
                    EatLimitCard(),
                    SizedBox(height: 24),
                    MealSuggestionsSection(),
                    SizedBox(height: 24),
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
