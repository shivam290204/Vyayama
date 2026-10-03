import 'package:fitbuddy/features/health_profile/data/condition_rule.dart';
import 'package:flutter/material.dart';

/// Expandable card with general notes and gentler options for a condition.
class ConditionDetailsCard extends StatelessWidget {
  /// Creates the card.
  const ConditionDetailsCard({super.key, required this.rule});

  /// The condition to describe.
  final ConditionRule rule;

  @override
  Widget build(BuildContext context) {
    if (rule.notes.isEmpty && rule.safeAlternatives.isEmpty) {
      return const SizedBox.shrink();
    }
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('About ${rule.label.toLowerCase()}', style: text.titleSmall),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (rule.notes.isNotEmpty)
            Text(rule.notes, style: text.bodyMedium),
          if (rule.safeAlternatives.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text('Gentler options to explore', style: text.labelLarge),
            const SizedBox(height: 4),
            for (final option in rule.safeAlternatives)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '\u2022 $option',
                  style: text.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
