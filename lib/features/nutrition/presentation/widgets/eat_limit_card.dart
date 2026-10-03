import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "Eat more of" and "Limit" lists, filtered for the user.
class EatLimitCard extends ConsumerWidget {
  /// Creates the card.
  const EatLimitCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: <Widget>[
        _TipGroup(
          title: 'Eat more of',
          icon: Icons.check_circle_outline,
          category: DietTip.eatMore,
          initiallyExpanded: true,
        ),
        const SizedBox(height: 12),
        _TipGroup(
          title: 'Limit',
          icon: Icons.remove_circle_outline,
          category: DietTip.limit,
        ),
      ],
    );
  }
}

class _TipGroup extends ConsumerWidget {
  const _TipGroup({
    required this.title,
    required this.icon,
    required this.category,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final String category;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tips = ref.watch(tipsByCategoryProvider(category));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, semanticLabel: title),
        title: Text(title, style: text.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AsyncValueView<List<DietTip>>(
            value: tips,
            onRetry: () => ref.invalidate(dietTipsProvider),
            builder: (list) {
              if (list.isEmpty) {
                return Text(
                  'Nothing to show right now.',
                  style: text.bodyMedium,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final tip in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(tip.title, style: text.titleSmall),
                          const SizedBox(height: 2),
                          Text(tip.body, style: text.bodyMedium),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
