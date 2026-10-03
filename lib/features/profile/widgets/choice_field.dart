import 'package:flutter/material.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';

/// Label plus a segmented single-choice control.
class ChoiceField extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;

  /// Map of stored value to display label (insertion order is kept).
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [
              for (final entry in options.entries)
                ButtonSegment(value: entry.key, label: Text(entry.value)),
            ],
            selected: value == null ? <String>{} : {value!},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onChanged(selection.first);
            },
          ),
        ),
      ],
    );
  }
}
