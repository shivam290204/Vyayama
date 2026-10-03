import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_labels.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Two-column grid of goal and body stats, shown in the chosen units.
class ProfileStats extends ConsumerWidget {
  const ProfileStats({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(unitSystemProvider);
    final weight = profile.weightKg;
    final height = profile.heightCm;

    final stats = <(String, String, IconData)>[
      ('Goal', ProfileLabels.goal(profile.goal), Icons.flag_rounded),
      ('Level', ProfileLabels.level(profile.fitnessLevel), Icons.bolt_rounded),
      ('Age', profile.age == null ? '-' : '${profile.age}', Icons.cake_outlined),
      ('Gender', ProfileLabels.gender(profile.gender), Icons.person_outline_rounded),
      (
        'Weight',
        weight == null ? '-' : UnitConversion.formatWeight(weight, unit),
        Icons.monitor_weight_outlined,
      ),
      (
        'Height',
        height == null ? '-' : UnitConversion.formatHeight(height, unit),
        Icons.height_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md) / 2;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: _StatCard(label: stat.$1, value: stat.$2, icon: stat.$3),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
