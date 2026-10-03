import 'dart:math' as math;

import 'package:fitbuddy/features/dashboard/calorie_math.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';

/// Today's calories split into resting (BMR) and active.
class CalorieBreakdownCard extends StatelessWidget {
  /// Creates the card.
  const CalorieBreakdownCard({super.key, required this.breakdown});

  /// Numbers to show.
  final CalorieBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final b = breakdown;
    final notes = <String>[
      if (b.activeIsEstimated) 'Active calories are estimated from your steps.',
      if (b.metricsEstimated)
        'Add your age, weight and height in your profile for a better estimate.',
      'Estimates for general wellness only, not medical advice.',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calories today', style: text.titleMedium),
            const SizedBox(height: 4),
            Text('${formatInt(b.total)} kcal', style: text.headlineMedium),
            Text('Resting (BMR) plus active', style: text.bodySmall),
            const SizedBox(height: 12),
            Semantics(
              label: 'Calorie breakdown',
              value: 'Resting ${formatInt(b.bmr)} kcal, '
                  'active ${formatInt(b.active)} kcal',
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      Expanded(
                        flex: math.max(1, b.bmr),
                        child: ColoredBox(color: scheme.secondary),
                      ),
                      if (b.active > 0)
                        Expanded(
                          flex: b.active,
                          child: ColoredBox(color: scheme.primary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _LegendRow(
              color: scheme.secondary,
              label: 'Resting (BMR, full day)',
              value: b.bmr,
            ),
            const SizedBox(height: 4),
            _LegendRow(
              color: scheme.primary,
              label: b.activeIsEstimated ? 'Active (estimated)' : 'Active',
              value: b.active,
            ),
            const SizedBox(height: 12),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  note,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: text.bodyMedium)),
        Text('${formatInt(value)} kcal', style: text.labelLarge),
      ],
    );
  }
}
