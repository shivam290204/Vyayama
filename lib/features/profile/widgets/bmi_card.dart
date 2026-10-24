import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/core/utils/unit_conversion.dart';
import 'package:fitbuddy/features/profile/data/profile.dart';
import 'package:fitbuddy/features/profile/logic/bmi_calculator.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:fitbuddy/features/profile/profile_validators.dart';
import 'package:fitbuddy/features/settings/providers.dart';

/// Card displayed on the Profile and BMI screens showing the user's BMI, clinical category,
/// educational disclaimer, quick height/weight editing, and access to weight tracking history.
class BmiCard extends ConsumerWidget {
  const BmiCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(unitSystemProvider);
    final bmiResult = ref.watch(currentBmiProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Body Mass Index (BMI)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, size: 20),
                  tooltip: 'About BMI',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showDisclaimerDialog(context, bmiResult),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (bmiResult == null)
              _buildMissingDataView(context, ref, theme, unit)
            else
              _buildBmiScoreView(context, theme, bmiResult, unit, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingDataView(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    UnitSystem unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Height and weight are required to calculate your BMI.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          onPressed: () => showEditDialog(context, ref, profile, unit),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add height & weight'),
        ),
      ],
    );
  }

  Widget _buildBmiScoreView(
    BuildContext context,
    ThemeData theme,
    BmiResult result,
    UnitSystem unit,
    WidgetRef ref,
  ) {
    final color = _getCategoryColor(result.category, theme);
    final heightStr = profile.heightCm != null
        ? UnitConversion.formatHeight(profile.heightCm!, unit)
        : 'Not set';
    final weightStr = profile.weightKg != null
        ? UnitConversion.formatWeight(profile.weightKg!, unit)
        : 'Not set';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              result.formattedBmi,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'kg/m²',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                result.categoryLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildBmiBar(result.bmi, theme),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.guidanceText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Interactive Height & Weight container inside the BMI card
        InkWell(
          onTap: () => showEditDialog(context, ref, profile, unit),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.height_rounded, size: 20, color: theme.colorScheme.primary),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.monitor_weight_outlined, size: 20, color: theme.colorScheme.primary),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _showHistorySheet(context, ref, unit),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: const Text('History'),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: () => showEditDialog(context, ref, profile, unit),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit Height & Weight'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBmiBar(double bmi, ThemeData theme) {
    final clamped = bmi.clamp(15.0, 35.0);
    final percent = (clamped - 15.0) / 20.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final indicatorX =
            ((totalWidth - 4) * percent).clamp(0.0, totalWidth - 4);

        return SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 2,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.deepOrange,
                      ],
                      stops: [0.15, 0.45, 0.70, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: indicatorX,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.black26, width: 0.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  void _showDisclaimerDialog(BuildContext context, BmiResult? result) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded),
              SizedBox(width: 8),
              Text('About BMI'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Body Mass Index (BMI) is an epidemiological screening indicator based on height and weight. '
              'It does not directly measure body fat percentage, muscle mass distribution, bone density, or metabolic health.\n\n'
              '• Athletes and muscular individuals may register in higher categories despite low body fat.\n'
              '• For children and teenagers under 20, adult categories do not apply; pediatric percentiles are used instead.\n'
              '• Vyayama uses your complete profile, activity, and goals—never BMI alone—to tailor workouts and nutrition suggestions.\n\n'
              'BMI is not a medical diagnosis. Consult a licensed healthcare professional for comprehensive health guidance.',
              style: TextStyle(height: 1.4),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  /// Global interactive dialog to manually edit height and weight, recalculating BMI immediately.
  static Future<void> showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    UnitSystem unit,
  ) async {
    final isMetric = unit == UnitSystem.metric;
    final cmController = TextEditingController();
    final ftController = TextEditingController();
    final inController = TextEditingController();
    final weightController = TextEditingController();
    final noteController = TextEditingController();

    if (profile.heightCm != null) {
      if (isMetric) {
        cmController.text = profile.heightCm!.round().toString();
      } else {
        final parts = UnitConversion.cmToFeetInches(profile.heightCm!);
        ftController.text = parts.feet.toString();
        inController.text = parts.inches.toString();
      }
    }

    if (profile.weightKg != null) {
      weightController.text = ProfileValidators.weightText(profile.weightKg!, unit);
    }

    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded),
              SizedBox(width: 8),
              Text('Edit Height & Weight'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Update your measurements to recalculate your BMI and adapt workout plans.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (isMetric) ...[
                    TextFormField(
                      controller: cmController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height_rounded),
                        hintText: 'e.g. 182',
                      ),
                      validator: ProfileValidators.heightCmField,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ftController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Feet',
                              prefixIcon: Icon(Icons.height_rounded),
                              hintText: 'e.g. 5',
                            ),
                            validator: ProfileValidators.feetField,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: TextFormField(
                            controller: inController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Inches',
                              hintText: 'e.g. 11',
                            ),
                            validator: ProfileValidators.inchesField,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Weight (${isMetric ? 'kg' : 'lb'})',
                      prefixIcon: const Icon(Icons.scale_rounded),
                      hintText: isMetric ? 'e.g. 80' : 'e.g. 176',
                    ),
                    validator: (val) => ProfileValidators.weight(val, unit),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                      hintText: 'e.g. morning weigh-in',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) {
                  return;
                }
                final newHeight = ProfileValidators.heightCm(
                  unit: unit,
                  cm: cmController.text,
                  ft: ftController.text,
                  inch: inController.text,
                );
                final newWeight = ProfileValidators.weightKg(weightController.text, unit);

                if (newHeight == null || newWeight == null) {
                  return;
                }

                Navigator.of(ctx).pop();

                final updatedProfile = profile.copyWith(
                  heightCm: newHeight,
                  weightKg: newWeight,
                );

                await ref.read(currentProfileProvider.notifier).save(updatedProfile);
                await ref.read(bmiHistoryProvider.notifier).recordMeasurement(
                      weightKg: newWeight,
                      heightCm: newHeight,
                      notes: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Height & weight updated! BMI recalculated.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showHistorySheet(BuildContext context, WidgetRef ref, UnitSystem unit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (sheetCtx, scrollController) {
            final historyAsync = ref.watch(bmiHistoryProvider);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Weight & BMI History',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: historyAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error loading history: $e')),
                      data: (records) {
                        if (records.isEmpty) {
                          return const Center(
                            child: Text(
                              'No historical weight entries logged yet.\nTap "Edit Height & Weight" to track changes over time.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scrollController,
                          itemCount: records.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (itemCtx, index) {
                            final r = records[index];
                            final formattedWeight =
                                UnitConversion.formatWeight(r.weightKg, unit);
                            final dateStr =
                                '${r.recordedAt.day}/${r.recordedAt.month}/${r.recordedAt.year}';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(r.bmi.toStringAsFixed(1)),
                              ),
                              title: Text(formattedWeight,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '$dateStr${r.notes != null ? ' · ${r.notes}' : ''}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                                tooltip: 'Delete entry',
                                onPressed: () {
                                  ref
                                      .read(bmiHistoryProvider.notifier)
                                      .deleteMeasurement(r.id);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
