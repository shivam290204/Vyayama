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
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final tips = ref.watch(tipsByCategoryProvider(category));
    final isEatMore = category == DietTip.eatMore;
    final iconColor = isEatMore ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          initiallyExpanded: initiallyExpanded,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, semanticLabel: title),
          ),
          title: Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AsyncValueView<List<DietTip>>(
              value: tips,
              onRetry: () => ref.invalidate(dietTipsProvider),
              builder: (list) {
                if (list.isEmpty) {
                  return Text(
                    'Nothing to show right now.',
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final tip in list)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(isEatMore ? Icons.check : Icons.close, color: iconColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(tip.title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(tip.body, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
