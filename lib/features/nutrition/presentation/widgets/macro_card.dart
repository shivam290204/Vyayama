import 'package:fitbuddy/core/theme/app_theme.dart';
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
    final isDark = scheme.brightness == Brightness.dark;

    final proteinColor = isDark ? AppPalette.limeGreen : AppPalette.forestGreen;
    final carbColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00);
    final fatColor = isDark ? const Color(0xFF4DD0E1) : const Color(0xFF0097A7);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.35 : 0.8,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Header ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: proteinColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: proteinColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Macronutrient Split',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Target: ${estimate.targetKcal} kcal/day',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- Proportional Macro Bar ---
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: macros.proteinPct,
                      child: Container(color: proteinColor),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: macros.carbPct,
                      child: Container(color: carbColor),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: macros.fatPct,
                      child: Container(color: fatColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- 3 Macro Stat Tiles ---
            Row(
              children: [
                Expanded(
                  child: _MacroTile(
                    label: 'Protein',
                    grams: macros.proteinG,
                    percent: macros.proteinPct,
                    kcal: macros.proteinG * 4,
                    color: proteinColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroTile(
                    label: 'Carbs',
                    grams: macros.carbG,
                    percent: macros.carbPct,
                    kcal: macros.carbG * 4,
                    color: carbColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroTile(
                    label: 'Fats',
                    grams: macros.fatG,
                    percent: macros.fatPct,
                    kcal: macros.fatG * 9,
                    color: fatColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.label,
    required this.grams,
    required this.percent,
    required this.kcal,
    required this.color,
  });

  final String label;
  final int grams;
  final int percent;
  final int kcal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.35 : 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${grams}g',
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$percent% · $kcal kcal',
            style: text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
