import 'package:fitbuddy/features/workouts/logic/labels.dart';
import 'package:flutter/material.dart';

/// Warning chips for exercise contraindication tags. Tags in [highlight]
/// (the user's own conditions) are shown in the error colors.
class ContraindicationChips extends StatelessWidget {
  const ContraindicationChips({
    super.key,
    required this.tags,
    this.highlight = const <String>{},
  });

  final List<String> tags;
  final Set<String> highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          Builder(builder: (context) {
            final hit = highlight.contains(tag.toLowerCase());
            return Chip(
              visualDensity: VisualDensity.compact,
              backgroundColor:
                  hit ? cs.errorContainer : cs.secondaryContainer,
              avatar: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: hit ? cs.onErrorContainer : cs.onSecondaryContainer,
                semanticLabel: 'Caution',
              ),
              label: Text(
                prettyLabel(tag),
                style: TextStyle(
                  color: hit ? cs.onErrorContainer : cs.onSecondaryContainer,
                ),
              ),
            );
          }),
      ],
    );
  }
}
