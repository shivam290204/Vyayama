import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/features/settings/widgets/settings_section.dart';
import 'package:fitbuddy/features/mascot/mascot_sound_service.dart';

/// Sound effects toggle.
class SoundSection extends ConsumerWidget {
  const SoundSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnabled = ref.watch(soundEnabledProvider);

    return SettingsSection(
      title: 'Sound',
      child: SwitchListTile.adaptive(
        title: const Text('Sound effects'),
        subtitle: const Text('Play a sound when the mascot celebrates'),
        value: isEnabled,
        onChanged: (_) => ref.read(soundEnabledProvider.notifier).toggle(),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
