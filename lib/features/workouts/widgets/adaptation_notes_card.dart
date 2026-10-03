import 'package:fitbuddy/features/workouts/logic/plan_adapter.dart';
import 'package:flutter/material.dart';

/// Explains which exercises were swapped or removed for the user's
/// conditions, plus a doctor reminder (spec 5.10).
class AdaptationNotesCard extends StatelessWidget {
  const AdaptationNotesCard({super.key, required this.notes});

  final List<AdaptationNote> notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded,
                    color: cs.onTertiaryContainer,
                    semanticLabel: 'Adjusted plan'),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Adjusted for your selected conditions',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: cs.onTertiaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${n.message}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onTertiaryContainer),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Please consult your doctor before starting a program.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
