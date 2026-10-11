import 'package:fitbuddy/features/home/providers/daily_completion_provider.dart';
import 'package:fitbuddy/features/mascot/mascot_mood.dart';
import 'package:fitbuddy/features/mascot/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Debug-only panel to force mascot mood and preview top mascot accomplishment tiers.
/// Renders nothing in release.
class MascotDebugPanel extends ConsumerWidget {
  /// Creates the panel.
  const MascotDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final forcedMood = ref.watch(mascotDebugMoodProvider);
    final moodNotifier = ref.read(mascotDebugMoodProvider.notifier);

    final forcedTier = ref.watch(dailyCompletionTierOverrideProvider);
    final tierNotifier = ref.read(dailyCompletionTierOverrideProvider.notifier);
    final progress = ref.watch(dailyCompletionProgressProvider);

    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debug: Top Mascot Progress Tier', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: Text('Auto (${progress.completedCount}/${progress.totalCount})'),
                  selected: forcedTier == null,
                  onSelected: (_) => tierNotifier.setTier(null),
                ),
                ChoiceChip(
                  label: const Text('0 Done (Sad)'),
                  selected: forcedTier == DailyCompletionTier.nothingDone,
                  onSelected: (_) =>
                      tierNotifier.setTier(DailyCompletionTier.nothingDone),
                ),
                ChoiceChip(
                  label: const Text('4-5 Done (Flex)'),
                  selected: forcedTier == DailyCompletionTier.fourToFiveDone,
                  onSelected: (_) =>
                      tierNotifier.setTier(DailyCompletionTier.fourToFiveDone),
                ),
                ChoiceChip(
                  label: const Text('All Done (Fire 🔥)'),
                  selected: forcedTier == DailyCompletionTier.everythingDone,
                  onSelected: (_) =>
                      tierNotifier.setTier(DailyCompletionTier.everythingDone),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Debug: Legacy Mood Override', style: textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Auto'),
                  selected: forcedMood == null,
                  onSelected: (_) => moodNotifier.force(null),
                ),
                for (final mood in MascotMood.values)
                  ChoiceChip(
                    label: Text(mood.label),
                    selected: forcedMood == mood,
                    onSelected: (_) => moodNotifier.force(mood),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
