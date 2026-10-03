import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/theme_provider.dart';
import 'package:fitbuddy/features/settings/widgets/settings_section.dart';

/// System / Light / Dark theme selector.
class ThemeSection extends ConsumerWidget {
  const ThemeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return SettingsSection(
      title: 'Appearance',
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ThemeMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_rounded),
              label: Text('System'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_rounded),
              label: Text('Light'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_rounded),
              label: Text('Dark'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) =>
              ref.read(themeModeProvider.notifier).setMode(selection.first),
        ),
      ),
    );
  }
}
