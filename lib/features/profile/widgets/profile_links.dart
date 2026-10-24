import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/logic/bmi_calculator.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Links from Profile to the features that are not bottom-bar tabs.
class ProfileLinks extends ConsumerWidget {
  const ProfileLinks({super.key, this.profile});

  final Profile? profile;

  static const List<(IconData, String, String)> _standardLinks = [
    (Icons.restaurant_menu_rounded, 'Nutrition', AppRoutes.nutrition),
    (Icons.favorite_border_rounded, 'Health', AppRoutes.health),
    (Icons.bedtime_outlined, 'Sleep', AppRoutes.sleep),
    (Icons.emoji_events_outlined, 'Challenges', AppRoutes.challenges),
    (Icons.groups_outlined, 'Teams', AppRoutes.teams),
    (Icons.auto_awesome_outlined, 'Daily Boost', AppRoutes.dailyBoost),
    (Icons.healing_rounded, 'Alarm Diagnostics', AppRoutes.notificationDiagnostics),
    (Icons.settings_outlined, 'Settings', AppRoutes.settings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final effectiveProfile =
        profile ?? ref.watch(currentProfileProvider).valueOrNull;
    final unit = ref.watch(unitSystemProvider);
    final bmiResult = ref.watch(currentBmiProvider);

    final heightStr = effectiveProfile?.heightCm != null
        ? UnitConversion.formatHeight(effectiveProfile!.heightCm!, unit)
        : null;
    final weightStr = effectiveProfile?.weightKg != null
        ? UnitConversion.formatWeight(effectiveProfile!.weightKg!, unit)
        : null;

    final String bmiSubtitle;
    if (heightStr != null && weightStr != null) {
      bmiSubtitle = 'Height: $heightStr  •  Weight: $weightStr';
    } else if (weightStr != null) {
      bmiSubtitle = 'Weight: $weightStr';
    } else if (heightStr != null) {
      bmiSubtitle = 'Height: $heightStr';
    } else {
      bmiSubtitle = 'Tap to record height & weight';
    }

    final bmiColor = bmiResult != null
        ? _getCategoryColor(bmiResult.category, theme)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Body Mass Index (BMI) link with integrated Height, Weight & BMI Score
          ListTile(
            minTileHeight: 64,
            leading: Icon(
              Icons.monitor_weight_outlined,
              color: bmiColor ?? theme.colorScheme.primary,
            ),
            title: const Text(
              'Body Mass Index (BMI)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              bmiSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bmiResult != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: bmiColor!.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bmiColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '${bmiResult.formattedBmi} • ${bmiResult.categoryLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: bmiColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            onTap: () => context.push(AppRoutes.bmi),
          ),
          const Divider(height: 1, indent: 56),

          // Remaining feature links
          for (var i = 0; i < _standardLinks.length; i++) ...[
            ListTile(
              minTileHeight: 56,
              leading: Icon(_standardLinks[i].$1),
              title: Text(_standardLinks[i].$2),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(_standardLinks[i].$3),
            ),
            if (i < _standardLinks.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Color _getCategoryColor(BmiCategory category, ThemeData theme) {
    return switch (category) {
      BmiCategory.underweight => Colors.blue,
      BmiCategory.normal => Colors.green,
      BmiCategory.overweight => Colors.orange,
      BmiCategory.obesity => Colors.red,
      BmiCategory.pediatric => theme.colorScheme.primary,
      BmiCategory.unclassified => theme.colorScheme.onSurfaceVariant,
    };
  }
}
