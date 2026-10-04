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
    final diet = ref.watch(dietTypeProvider);
    final relevant = ref.watch(relevantConditionKeysProvider);
    final onlyFriendly = ref.watch(conditionFriendlyOnlyProvider);
    final meals = ref.watch(suggestedMealsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Meal ideas', style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Calories are approximate. These are general ideas, not a diet plan.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        SegmentedButton<DietType>(
          style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
          showSelectedIcon: false,
          segments: <ButtonSegment<DietType>>[
            for (final type in DietType.values)
              ButtonSegment<DietType>(value: type, label: Text(type.label)),
          ],
          selected: <DietType>{diet},
          onSelectionChanged: (s) =>
              ref.read(dietTypeProvider.notifier).select(s.first),
        ),
        if (relevant.isNotEmpty)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Suited to my conditions'),
            subtitle: const Text('Shows meals that generally fit your choices'),
            value: onlyFriendly,
            onChanged: (v) =>
                ref.read(conditionFriendlyOnlyProvider.notifier).set(v),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final type in MealType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: _filter == type,
                onSelected: (_) => setState(() => _filter = type),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AsyncValueView<List<Meal>>(
          value: meals,
          onRetry: () => ref.invalidate(mealsProvider),
          builder: (all) {
            final list = _filter == null
                ? all
                : all.where((m) => m.mealType == _filter).toList();
            if (list.isEmpty) return const _EmptyMeals();
            return Column(
              children: <Widget>[for (final meal in list) _MealCard(meal: meal)],
            );
          },
        ),
      ],
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
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu,
              size: 40,
              color: scheme.onSurfaceVariant,
              semanticLabel: 'No meals found',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No meals match these choices.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try another diet type or turn off the conditions filter to see more options.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final Meal meal;

  IconData get _icon => switch (meal.mealType) {
        MealType.breakfast => Icons.free_breakfast_outlined,
        MealType.lunch => Icons.lunch_dining_outlined,
        MealType.snack => Icons.bakery_dining_outlined,
        MealType.dinner => Icons.dinner_dining_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_icon, color: scheme.primary, size: 32, semanticLabel: meal.mealType.label),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(meal.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      if (meal.cuisine == 'indian')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Indian', style: text.labelSmall?.copyWith(color: Colors.orange)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(meal.description, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('${meal.calories} kcal', style: text.labelMedium?.copyWith(color: Colors.orange, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Icon(Icons.fitness_center, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('${meal.proteinG}g protein', style: text.labelMedium?.copyWith(color: Colors.green, fontWeight: FontWeight.w600)),
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
