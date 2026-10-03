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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.restaurant_menu,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              semanticLabel: 'No meals found',
            ),
            const SizedBox(height: 8),
            const Text(
              'No meals match these choices. Try another diet type or turn '
              'off the conditions filter.',
              textAlign: TextAlign.center,
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

  IconData get _icon => switch (meal.mealType) {
        MealType.breakfast => Icons.free_breakfast_outlined,
        MealType.lunch => Icons.lunch_dining_outlined,
        MealType.snack => Icons.bakery_dining_outlined,
        MealType.dinner => Icons.dinner_dining_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: Icon(_icon, semanticLabel: meal.mealType.label),
        title: Text(meal.name),
        subtitle: Text(
          '${meal.description}\n'
          'About ${meal.calories} kcal · ${meal.proteinG} g protein',
        ),
        trailing: meal.cuisine == 'indian'
            ? Icon(
                Icons.location_on_outlined,
                color: scheme.onSurfaceVariant,
                semanticLabel: 'Indian dish',
              )
            : null,
      ),
    );
  }
}
