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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Icon(Icons.pie_chart_outline, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Macro Tracker', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  widthFactor: 0.85,
                  child: _MacroRing(
                    icon: Icons.fitness_center,
                    label: 'PROTEIN',
                    grams: macros.proteinG,
                    percent: macros.proteinPct,
                    color: scheme.primary,
                  ),
                ),
                Align(
                  widthFactor: 0.85,
                  child: _MacroRing(
                    icon: Icons.local_fire_department,
                    label: 'CARBS',
                    grams: macros.carbG,
                    percent: macros.carbPct,
                    color: scheme.secondary,
                  ),
                ),
                _MacroRing(
                  icon: Icons.water_drop,
                  label: 'FATS',
                  grams: macros.fatG,
                  percent: macros.fatPct,
                  color: scheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: isDark ? 0.2 : 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DAILY CALORIES', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '${estimate.targetKcal}', 
                                style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                ' / ${estimate.highKcal} kcal', 
                                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('SUMMARY', style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '100%', 
                            style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.secondary, scheme.tertiary],
                      ),
                    ),
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

class _MacroRing extends StatelessWidget {
  const _MacroRing({
    required this.icon,
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int grams;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent / 100),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          width: 105,
          height: 105,
          child: CustomPaint(
            painter: _GlowingRingPainter(progress: value, color: color),
            child: child,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(
              label, 
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 0.5)
            ),
            const SizedBox(height: 2),
            Text(
              '${grams}g', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)
            ),
            Text(
              '$percent%', 
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowingRingPainter extends CustomPainter {
  _GlowingRingPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const stroke = 8.0;

    // Draw background track
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -3.14159 / 2; // start at top
    final sweepAngle = 2 * 3.14159 * progress;

    if (progress > 0) {
      // Draw simulated glow (much faster than MaskFilter.blur on web)
      for (int i = 0; i < 3; i++) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.15 - (i * 0.05))
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke + (3 - i) * 4
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      }

      // Draw solid arc
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowingRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
