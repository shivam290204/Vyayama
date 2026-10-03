import 'package:fitbuddy/features/snaps/data/activity_type.dart';
import 'package:flutter/material.dart';

/// Single-select activity tag chips.
class ActivityChips extends StatelessWidget {
  const ActivityChips({super.key, required this.selected, required this.onSelected});

  final ActivityType? selected;
  final ValueChanged<ActivityType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in ActivityType.selectable)
          ChoiceChip(
            avatar: Icon(a.icon, size: 18),
            label: Text(a.label),
            selected: selected == a,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onSelected(a),
          ),
      ],
    );
  }
}
