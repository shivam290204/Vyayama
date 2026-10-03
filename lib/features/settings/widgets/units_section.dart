import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/settings/providers.dart';
import 'package:fitbuddy/features/settings/widgets/settings_section.dart';

/// Metric / imperial selector. Stored data stays metric.
class UnitsSection extends ConsumerWidget {
  const UnitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(unitSystemProvider);

    return SettingsSection(
      title: 'Units',
      subtitle: 'Changes how weight and height are shown.',
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<UnitSystem>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: UnitSystem.metric, label: Text('kg / cm')),
            ButtonSegment(value: UnitSystem.imperial, label: Text('lb / ft')),
          ],
          selected: {unit},
          onSelectionChanged: (selection) =>
              ref.read(unitSystemProvider.notifier).setSystem(selection.first),
        ),
      ),
    );
  }
}
