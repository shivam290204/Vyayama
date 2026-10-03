import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug-only panel to force each mascot mood. Renders nothing in release.
class MascotDebugPanel extends ConsumerWidget {
  /// Creates the panel.
  const MascotDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final forced = ref.watch(mascotDebugMoodProvider);
    final notifier = ref.read(mascotDebugMoodProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug: force mascot mood', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Auto'),
                  selected: forced == null,
                  onSelected: (_) => notifier.force(null),
                ),
                for (final mood in MascotMood.values)
                  ChoiceChip(
                    label: Text(mood.label),
                    selected: forced == mood,
                    onSelected: (_) => notifier.force(mood),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
