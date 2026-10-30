import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/nutrition/data/meal.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Meal ideas filtered by diet type, goal and health conditions.
class MealSuggestionsSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const MealSuggestionsSection({super.key});

  @override
  ConsumerState<MealSuggestionsSection> createState() =>
      _MealSuggestionsSectionState();
}

class _MealSuggestionsSectionState
    extends ConsumerState<MealSuggestionsSection> {
  MealType? _filter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final diet = ref.watch(dietTypeProvider);
    final relevant = ref.watch(relevantConditionKeysProvider);
    final onlyFriendly = ref.watch(conditionFriendlyOnlyProvider);
    final meals = ref.watch(suggestedMealsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // --- Section Header ---
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? AppPalette.limeGreen : AppPalette.forestGreen)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.restaurant_menu_rounded,
                color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meal Ideas',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Nutrient-balanced dishes fitted to your daily target',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // --- Diet Type Segmented Bar (Solid Dark Green on Select) ---
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(
              alpha: isDark ? 0.35 : 0.65,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outline.withValues(alpha: isDark ? 0.18 : 0.3),
            ),
          ),
          child: Row(
            children: [
              for (final type in DietType.values)
                Expanded(
                  child: _DietTypePill(
                    type: type,
                    isSelected: diet == type,
                    onTap: () =>
                        ref.read(dietTypeProvider.notifier).select(type),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- Meal Time Horizontal Filter Chips ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _MealTimeChip(
                label: 'All',
                icon: Icons.grid_view_rounded,
                isSelected: _filter == null,
                onTap: () => setState(() => _filter = null),
              ),
              const SizedBox(width: 8),
              for (final type in MealType.values) ...[
                _MealTimeChip(
                  label: type.label,
                  icon: _resolveMealTimeIcon(type),
                  isSelected: _filter == type,
                  onTap: () => setState(() => _filter = type),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),

        // --- Health Condition Toggle (Compact & Sleek) ---
        if (relevant.isNotEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => ref
                .read(conditionFriendlyOnlyProvider.notifier)
                .set(!onlyFriendly),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: onlyFriendly
                    ? (isDark
                            ? AppPalette.limeGreen
                            : AppPalette.forestGreen)
                        .withValues(alpha: isDark ? 0.16 : 0.08)
                    : scheme.surfaceContainerHighest.withValues(
                        alpha: isDark ? 0.25 : 0.5,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: onlyFriendly
                      ? (isDark
                              ? AppPalette.limeGreen
                              : AppPalette.forestGreen)
                          .withValues(alpha: 0.35)
                      : scheme.outline.withValues(alpha: isDark ? 0.15 : 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    onlyFriendly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 16,
                    color: onlyFriendly
                        ? (isDark
                            ? AppPalette.limeGreen
                            : AppPalette.forestGreen)
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Suited to my health conditions',
                      style: text.labelMedium?.copyWith(
                        fontWeight:
                            onlyFriendly ? FontWeight.bold : FontWeight.w500,
                        color: onlyFriendly
                            ? (isDark
                                ? AppPalette.limeGreen
                                : AppPalette.forestGreen)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: onlyFriendly,
                    onChanged: (v) => ref
                        .read(conditionFriendlyOnlyProvider.notifier)
                        .set(v),
                    activeTrackColor:
                        isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // --- Meals List ---
        AsyncValueView<List<Meal>>(
          value: meals,
          onRetry: () => ref.invalidate(mealsProvider),
          builder: (all) {
            final list = _filter == null
                ? all
                : all.where((m) => m.mealType == _filter).toList();
            if (list.isEmpty) return const _EmptyMeals();
            return Column(
              children: <Widget>[
                for (final meal in list) _MealCard(meal: meal),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DietTypePill extends StatelessWidget {
  const _DietTypePill({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final DietType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.forestGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.forestGreen.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            type.label,
            style: text.labelMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _MealTimeChip extends StatelessWidget {
  const _MealTimeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final activeColor = isDark ? AppPalette.limeGreen : AppPalette.forestGreen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
              : scheme.surface.withValues(alpha: isDark ? 0.35 : 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.5)
                : scheme.outline.withValues(alpha: isDark ? 0.16 : 0.3),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? activeColor : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: text.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    final dishIcon = _resolveMealIcon(meal);
    final primaryAccent =
        isDark ? AppPalette.limeGreen : AppPalette.forestGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.35 : 0.8,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.18 : 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dish Icon in Rounded Squircle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primaryAccent.withValues(alpha: isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(dishIcon, color: primaryAccent, size: 22),
            ),
            const SizedBox(width: 14),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Veg/NonVeg Indicator
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          meal.name,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DietIndicator(dietType: meal.dietType),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    meal.description,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Macros & Badges Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Calorie Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.warning
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 14,
                              color: context.colors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${meal.calories} kcal',
                              style: text.labelSmall?.copyWith(
                                color: context.colors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Protein Pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: primaryAccent
                              .withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 13,
                              color: primaryAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${meal.proteinG}g protein',
                              style: text.labelSmall?.copyWith(
                                color: primaryAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Indian Cuisine Badge
                      if (meal.cuisine == 'indian')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.outline
                                  .withValues(alpha: isDark ? 0.2 : 0.3),
                            ),
                          ),
                          child: Text(
                            'Indian',
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                            ),
                          ),
                        ),

                      // Condition Friendly Badge
                      if (meal.conditionFriendly.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: primaryAccent.withValues(
                              alpha: isDark ? 0.15 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: primaryAccent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Health Friendly',
                                style: text.labelSmall?.copyWith(
                                  color: primaryAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Authentic Veg / Non-Veg / Vegan indicator icon.
class _DietIndicator extends StatelessWidget {
  const _DietIndicator({required this.dietType});

  final DietType dietType;

  @override
  Widget build(BuildContext context) {
    if (dietType == DietType.vegan) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppPalette.forestGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, size: 12, color: AppPalette.forestGreen),
            SizedBox(width: 2),
            Text(
              'Vegan',
              style: TextStyle(
                fontSize: 10,
                color: AppPalette.forestGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final isVeg = dietType == DietType.veg;
    final color = isVeg ? AppPalette.forestGreen : AppPalette.error;

    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.35 : 0.75,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.18 : 0.35),
        ),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 32,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No meals match these choices.',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try switching diet type or turn off the condition filter to see more options.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

IconData _resolveMealTimeIcon(MealType type) => switch (type) {
      MealType.breakfast => Icons.wb_twilight_rounded,
      MealType.lunch => Icons.wb_sunny_rounded,
      MealType.snack => Icons.coffee_rounded,
      MealType.dinner => Icons.nights_stay_rounded,
    };

IconData _resolveMealIcon(Meal meal) {
  final name = meal.name.toLowerCase();

  if (name.contains('egg') ||
      name.contains('omelette') ||
      name.contains('bhurji')) {
    return Icons.egg_rounded;
  }
  if (name.contains('chicken') || name.contains('tikka')) {
    return Icons.kebab_dining_rounded;
  }
  if (name.contains('fish')) {
    return Icons.set_meal_rounded;
  }
  if (name.contains('poha') ||
      name.contains('upma') ||
      name.contains('chilla') ||
      name.contains('idli') ||
      name.contains('dosa') ||
      name.contains('paratha')) {
    return Icons.breakfast_dining_rounded;
  }
  if (name.contains('dal') ||
      name.contains('rajma') ||
      name.contains('chana') ||
      name.contains('khichdi') ||
      name.contains('sambar') ||
      name.contains('stew') ||
      name.contains('soup')) {
    return Icons.soup_kitchen_rounded;
  }
  if (name.contains('rice') ||
      name.contains('pulao') ||
      name.contains('quinoa') ||
      name.contains('oats')) {
    return Icons.rice_bowl_rounded;
  }
  if (name.contains('smoothie') || name.contains('shake')) {
    return Icons.local_drink_rounded;
  }
  if (name.contains('salad') || name.contains('sprouts')) {
    return Icons.eco_rounded;
  }
  if (name.contains('nut') ||
      name.contains('peanut') ||
      name.contains('makhana')) {
    return Icons.grain_rounded;
  }
  if (name.contains('paneer') || name.contains('curd')) {
    return Icons.lunch_dining_rounded;
  }

  return switch (meal.mealType) {
    MealType.breakfast => Icons.free_breakfast_rounded,
    MealType.lunch => Icons.lunch_dining_rounded,
    MealType.snack => Icons.bakery_dining_rounded,
    MealType.dinner => Icons.dinner_dining_rounded,
  };
}
