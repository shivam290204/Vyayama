import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/profile/data/bmi_record.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/widgets/bmi_card.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Dedicated screen for Body Mass Index (BMI) screening, tracking, and education.
class BmiScreen extends ConsumerWidget {
  const BmiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    final unit = ref.watch(unitSystemProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Mass Index (BMI)'),
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: AppSpacing.md),
                const Text('Could not load profile data.'),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => ref.invalidate(currentProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    const Text('No profile found.'),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.home),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              );
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Summary metric chips (tap to edit height/weight)
                    _buildMetricsHeader(context, ref, profile, unit, theme),
                    const SizedBox(height: AppSpacing.lg),

                    // Main Interactive BMI Card
                    BmiCard(profile: profile),
                    const SizedBox(height: AppSpacing.lg),

                    // Dedicated Card to change/edit Height & Weight manually inside BMI
                    _buildEditHeightWeightCard(context, ref, profile, unit, theme),
                    const SizedBox(height: AppSpacing.lg),

                    // Standard Reference Ranges Card
                    _buildReferenceCard(theme),
                    const SizedBox(height: AppSpacing.lg),

                    // Clinical Context Card
                    _buildContextCard(theme),
                    const SizedBox(height: AppSpacing.lg),

                    // History Section
                    _buildRecentHistorySection(context, ref, profile, unit, theme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMetricsHeader(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    UnitSystem unit,
    ThemeData theme,
  ) {
    final weightStr = profile.weightKg != null
        ? UnitConversion.formatWeight(profile.weightKg!, unit)
        : 'Not set';
    final heightStr = profile.heightCm != null
        ? UnitConversion.formatHeight(profile.heightCm!, unit)
        : 'Not set';
    final ageStr = profile.age != null ? '${profile.age} yrs' : 'Not set';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        onTap: () => BmiCard.showEditDialog(context, ref, profile, unit),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(theme, 'Weight', weightStr, Icons.scale_rounded),
              _buildMetricDivider(theme),
              _buildMetricItem(theme, 'Height', heightStr, Icons.height_rounded),
              _buildMetricDivider(theme),
              _buildMetricItem(theme, 'Age', ageStr, Icons.cake_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditHeightWeightCard(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    UnitSystem unit,
    ThemeData theme,
  ) {
    final heightStr = profile.heightCm != null
        ? UnitConversion.formatHeight(profile.heightCm!, unit)
        : 'Not set';
    final weightStr = profile.weightKg != null
        ? UnitConversion.formatWeight(profile.weightKg!, unit)
        : 'Not set';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Height & Weight',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Manually adjust your measurements to update BMI',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => BmiCard.showEditDialog(context, ref, profile, unit),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.height_rounded, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Height',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  heightStr,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () => BmiCard.showEditDialog(context, ref, profile, unit),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.scale_rounded, color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weight',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  weightStr,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => BmiCard.showEditDialog(context, ref, profile, unit),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Edit Height & Weight'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 36,
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildMetricItem(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Adult BMI Standard Ranges',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildCategoryRow('Underweight', '< 18.5', Colors.blue, theme),
            const Divider(height: 12),
            _buildCategoryRow('Normal weight', '18.5 – 24.9', Colors.green, theme),
            const Divider(height: 12),
            _buildCategoryRow('Overweight', '25.0 – 29.9', Colors.orange, theme),
            const Divider(height: 12),
            _buildCategoryRow('Obesity', '≥ 30.0', Colors.red, theme),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.child_care_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'For ages under 20, pediatric percentiles are used. Adult categories do not apply.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(
    String category,
    String range,
    Color color,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              category,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            range,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContextCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'How Vyayama Uses Your BMI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'BMI serves as a baseline screening indicator. Vyayama combines it with your fitness level, joint considerations, daily hydration, and activity consistency to tailor safe, effective routines.\n\n'
              'Because BMI cannot distinguish between lean muscle and adipose tissue, muscular athletes may fall into higher tiers. Always prioritize how you feel, your stamina, and your functional mobility.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHistorySection(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    UnitSystem unit,
    ThemeData theme,
  ) {
    final historyAsync = ref.watch(bmiHistoryProvider);

    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (records) {
        if (records.isEmpty) return const SizedBox.shrink();

        final recent = records.take(5).toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Recent Logs',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final rec in recent) _buildHistoryTile(rec, unit, theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTile(BmiRecord rec, UnitSystem unit, ThemeData theme) {
    final dateStr =
        '${rec.recordedAt.day}/${rec.recordedAt.month}/${rec.recordedAt.year}';
    final weightStr = UnitConversion.formatWeight(rec.weightKg, unit);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rec.bmi.toStringAsFixed(1),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            weightStr,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            dateStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
