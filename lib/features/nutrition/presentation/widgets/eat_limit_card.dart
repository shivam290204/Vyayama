import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/nutrition/data/diet_tip.dart';
import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _GuideTab { eatMore, limit }

/// Clean, human-designed food guide displaying foods to prioritize and moderate.
class EatLimitCard extends ConsumerStatefulWidget {
  /// Creates the food guide card.
  const EatLimitCard({super.key});

  @override
  ConsumerState<EatLimitCard> createState() => _EatLimitCardState();
}

class _EatLimitCardState extends ConsumerState<EatLimitCard> {
  _GuideTab _selectedTab = _GuideTab.eatMore;
  bool _showAllEatMore = false;
  bool _showAllLimit = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    final eatMoreTips = ref.watch(tipsByCategoryProvider(DietTip.eatMore));
    final limitTips = ref.watch(tipsByCategoryProvider(DietTip.limit));

    final diet = ref.watch(dietTypeProvider);
    final effectiveGoal = ref.watch(effectiveGoalProvider);

    final goalLabel = switch (effectiveGoal) {
      NutritionGoal.lose => 'Fat Loss',
      NutritionGoal.gain => 'Muscle Gain',
      NutritionGoal.maintain => 'Maintenance',
    };

    final eatMoreCount = eatMoreTips.valueOrNull?.length ?? 0;
    final limitCount = limitTips.valueOrNull?.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.35 : 0.8,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.2 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- Header ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? AppPalette.limeGreen : AppPalette.forestGreen)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: isDark ? AppPalette.limeGreen : AppPalette.forestGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Food Guide',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tailored to your ${diet.label} diet · $goalLabel',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Segmented Tab Switcher ---
            _SegmentControl(
              selectedTab: _selectedTab,
              eatMoreCount: eatMoreCount,
              limitCount: limitCount,
              onTabSelected: (tab) => setState(() => _selectedTab = tab),
            ),
            const SizedBox(height: 14),

            // --- Content View ---
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: switch (_selectedTab) {
                _GuideTab.eatMore => _FoodListView(
                    key: const ValueKey('eat_more_list'),
                    asyncTips: eatMoreTips,
                    isEatMore: true,
                    showAll: _showAllEatMore,
                    onToggleShowAll: () =>
                        setState(() => _showAllEatMore = !_showAllEatMore),
                  ),
                _GuideTab.limit => _FoodListView(
                    key: const ValueKey('limit_list'),
                    asyncTips: limitTips,
                    isEatMore: false,
                    showAll: _showAllLimit,
                    onToggleShowAll: () =>
                        setState(() => _showAllLimit = !_showAllLimit),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentControl extends StatelessWidget {
  const _SegmentControl({
    required this.selectedTab,
    required this.eatMoreCount,
    required this.limitCount,
    required this.onTabSelected,
  });

  final _GuideTab selectedTab;
  final int eatMoreCount;
  final int limitCount;
  final ValueChanged<_GuideTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.4 : 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.18 : 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'Eat more of',
              count: eatMoreCount,
              icon: Icons.check_circle_outline_rounded,
              isSelected: selectedTab == _GuideTab.eatMore,
              activeColor: AppPalette.forestGreen,
              onTap: () => onTabSelected(_GuideTab.eatMore),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              title: 'Limit',
              count: limitCount,
              icon: Icons.remove_circle_outline_rounded,
              isSelected: selectedTab == _GuideTab.limit,
              activeColor: AppPalette.error,
              onTap: () => onTabSelected(_GuideTab.limit),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: text.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodListView extends ConsumerWidget {
  const _FoodListView({
    super.key,
    required this.asyncTips,
    required this.isEatMore,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final AsyncValue<List<DietTip>> asyncTips;
  final bool isEatMore;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AsyncValueView<List<DietTip>>(
      value: asyncTips,
      onRetry: () => ref.invalidate(dietTipsProvider),
      builder: (tips) {
        if (tips.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No items found for this selection.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final visibleTips = showAll ? tips : tips.take(4).toList();

        return Column(
          children: [
            for (final tip in visibleTips)
              _FoodTile(
                tip: tip,
                isEatMore: isEatMore,
              ),
            if (tips.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: TextButton.icon(
                    onPressed: onToggleShowAll,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                    icon: Icon(
                      showAll
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    label: Text(
                      showAll
                          ? 'Show less'
                          : 'Show all ${tips.length} recommendations',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.tip,
    required this.isEatMore,
  });

  final DietTip tip;
  final bool isEatMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isDark = scheme.brightness == Brightness.dark;

    final accentColor = isEatMore
        ? (isDark ? AppPalette.limeGreen : AppPalette.forestGreen)
        : context.colors.warning;

    final icon = _resolveFoodIcon(tip.id, tip.title, isEatMore);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? 0.45 : 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: isDark ? 0.16 : 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tip.body,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            isEatMore ? Icons.check_rounded : Icons.remove_rounded,
            color: accentColor.withValues(alpha: 0.6),
            size: 18,
          ),
        ],
      ),
    );
  }
}

IconData _resolveFoodIcon(String id, String title, bool isEatMore) {
  final cleanId = id.toLowerCase();
  final t = title.toLowerCase();

  if (isEatMore) {
    if (cleanId == 't01' || t.contains('vegetable')) return Icons.eco_rounded;
    if (cleanId == 't02' || t.contains('grain') || t.contains('rice') || t.contains('oat')) {
      return Icons.grain_rounded;
    }
    if (cleanId == 't03' || t.contains('dal') || t.contains('pulse') || t.contains('sprout')) {
      return Icons.egg_alt_rounded;
    }
    if (cleanId == 't04' || t.contains('fruit')) return Icons.apple_rounded;
    if (cleanId == 't05' || t.contains('egg') || t.contains('chicken') || t.contains('fish')) {
      return Icons.set_meal_rounded;
    }
    if (cleanId == 't06' || t.contains('paneer') || t.contains('curd') || t.contains('milk')) {
      return Icons.local_drink_rounded;
    }
    if (cleanId == 't07' || t.contains('tofu') || t.contains('soy')) return Icons.grass_rounded;
    if (cleanId == 't08' || t.contains('nut') || t.contains('seed')) {
      return Icons.scatter_plot_rounded;
    }
    if (cleanId == 't09' || t.contains('extra') || t.contains('calorie')) return Icons.bolt_rounded;
    if (cleanId == 't10' || t.contains('fibre') || t.contains('salad')) return Icons.spa_rounded;
    return Icons.check_circle_outline_rounded;
  } else {
    if (cleanId == 't11' || t.contains('sugary drink') || t.contains('cold drink') || t.contains('chai')) {
      return Icons.local_cafe_rounded;
    }
    if (cleanId == 't12' || t.contains('fried') || t.contains('samosa') || t.contains('pakora')) {
      return Icons.lunch_dining_rounded;
    }
    if (cleanId == 't13' || t.contains('sweet') || t.contains('dessert') || t.contains('mithai')) {
      return Icons.cake_rounded;
    }
    if (cleanId == 't14' || t.contains('maida') || t.contains('flour') || t.contains('noodle')) {
      return Icons.bakery_dining_rounded;
    }
    if (cleanId == 't15' || t.contains('salty') || t.contains('chips') || t.contains('namkeen')) {
      return Icons.shopping_bag_outlined;
    }
    if (cleanId == 't16' || t.contains('processed') || t.contains('meat')) {
      return Icons.kebab_dining_rounded;
    }
    if (cleanId == 't17' || t.contains('white rice')) return Icons.rice_bowl_rounded;
    if (cleanId == 't18' || t.contains('skipping') || t.contains('gap')) {
      return Icons.alarm_off_rounded;
    }
    if (cleanId == 't19' || t.contains('salt')) return Icons.science_outlined;
    if (cleanId == 't20' || t.contains('sugar')) return Icons.no_drinks_rounded;
    return Icons.remove_circle_outline_rounded;
  }
}
