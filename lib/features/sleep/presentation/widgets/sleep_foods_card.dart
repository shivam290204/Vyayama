import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Foods that may suit, or are better avoided, close to bedtime.
class SleepFoodsCard extends ConsumerWidget {
  /// Creates the card.
  const SleepFoodsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Food and drink near bedtime', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'General ideas only. Everyone is different.',
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            const _TipList(
              title: 'Good choices',
              icon: Icons.check_circle_outline,
              category: DietTip.sleepEat,
            ),
            const SizedBox(height: 12),
            const _TipList(
              title: 'Better to avoid',
              icon: Icons.remove_circle_outline,
              category: DietTip.sleepAvoid,
            ),
          ],
        ),
      ),
    );
  }
}

class _TipList extends ConsumerWidget {
  const _TipList({
    required this.title,
    required this.icon,
    required this.category,
  });

  final String title;
  final IconData icon;
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 20, color: scheme.primary, semanticLabel: title),
            const SizedBox(width: 8),
            Text(title, style: text.titleSmall),
          ],
        ),
        const SizedBox(height: 4),
        AsyncValueView<List<DietTip>>(
          value: ref.watch(sleepTipsProvider(category)),
          onRetry: () => ref.invalidate(dietTipsProvider),
          loadingHeight: 60,
          builder: (tips) {
            if (tips.isEmpty) {
              return Text('Nothing to show right now.', style: text.bodyMedium);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final tip in tips)
                  Padding(
                    padding: const EdgeInsets.only(left: 28, top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(tip.title, style: text.bodyMedium),
                        Text(
                          tip.body,
                          style: text.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
