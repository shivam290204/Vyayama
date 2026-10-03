import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Suggested protein, carbohydrate and fat split for the calorie target.
class MacroCard extends ConsumerWidget {
  /// Creates the card.
  const MacroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = ref.watch(calorieEstimateProvider);
    if (estimate == null) return const SizedBox.shrink();

    final macros = NutritionCalculator.macros(
      kcal: estimate.targetKcal,
      goal: estimate.effectiveGoal,
    );
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final parts = <_MacroPart>[
      _MacroPart('Protein', macros.proteinPct, macros.proteinG, scheme.primary),
      _MacroPart('Carbs', macros.carbPct, macros.carbG, scheme.secondary),
      _MacroPart('Fat', macros.fatPct, macros.fatG, scheme.tertiary),
    ];
    final summary = parts
        .map((p) => '${p.label} ${p.percent} percent, ${p.grams} grams')
        .join('. ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Macro split suggestion', style: text.titleMedium),
            const SizedBox(height: 12),
            Semantics(
              label: 'Macro split. $summary',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: <Widget>[
                      for (final p in parts)
                        Expanded(
                          flex: p.percent,
                          child: Container(height: 14, color: p.color),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final p in parts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: p.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.label, style: text.bodyMedium)),
                    Text(
                      '${p.percent}%  ·  about ${p.grams} g',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'A general starting point. Adjust to what feels good for you.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPart {
  const _MacroPart(this.label, this.percent, this.grams, this.color);

  final String label;
  final int percent;
  final int grams;
  final Color color;
}
