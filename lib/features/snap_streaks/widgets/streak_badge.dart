import 'package:flutter/material.dart';

/// Flame plus day count, e.g. "🔥 12". Shows ⏳ when the streak is at risk.
class StreakBadge extends StatelessWidget {
  const StreakBadge({
    super.key,
    required this.count,
    this.atRisk = false,
    this.large = false,
  });

  final int count;
  final bool atRisk;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = count == 0
        ? scheme.outline
        : (atRisk ? scheme.error : scheme.tertiary);
    final style = (large ? text.headlineSmall : text.titleMedium)
        ?.copyWith(color: color, fontWeight: FontWeight.w700);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: count == 0
          ? 'No streak yet'
          : '$count day streak${atRisk ? ', at risk' : ''}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department, color: color, size: large ? 32 : 24),
          const SizedBox(width: 4),
          Text('$count', style: style),
          if (atRisk) Text(' ⏳', style: style),
        ],
      ),
    );
  }
}
