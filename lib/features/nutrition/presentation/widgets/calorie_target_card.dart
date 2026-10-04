import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/health_profile/data/profile_snapshot.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/nutrition/domain/nutrition_calculator.dart';
import 'package:fitbuddy/features/nutrition/presentation/widgets/format.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:fitbuddy/features/profile/profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shows the estimated daily calorie range with goal and activity pickers.
class CalorieTargetCard extends ConsumerWidget {
  /// Creates the card.
  const CalorieTargetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileSnapshotProvider);
    return AsyncValueView<ProfileSnapshot?>(
      value: profile,
      onRetry: () => ref.invalidate(currentProfileProvider),
      builder: (snapshot) {
        final estimate = ref.watch(calorieEstimateProvider);
        if (estimate == null) return const _MissingInfoCard();
        return _EstimateBody(
          estimate: estimate,
          isMinor: (snapshot?.age ?? 18) < 18,
        );
      },
    );
  }
}

class _MissingInfoCard extends StatelessWidget {
  const _MissingInfoCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Your daily calorie estimate', style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Add your age, height and weight in your profile to see an '
              'estimate.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => context.go(AppRoutes.profile),
              icon: const Icon(Icons.person),
              label: const Text('Open profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateBody extends ConsumerWidget {
  const _EstimateBody({required this.estimate, required this.isMinor});

  final CalorieEstimate estimate;
  final bool isMinor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final activity = ref.watch(activityLevelProvider);
    final isDark = scheme.brightness == Brightness.dark;
    final goals = <NutritionGoal>[
      if (!isMinor) NutritionGoal.lose,
      NutritionGoal.maintain,
      NutritionGoal.gain,
    ];

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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.local_fire_department, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Daily Calorie Target', style: text.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Your Goal', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<NutritionGoal>(
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: scheme.surface.withValues(alpha: 0.5),
              ),
              showSelectedIcon: true,
              segments: <ButtonSegment<NutritionGoal>>[
                for (final goal in goals)
                  ButtonSegment<NutritionGoal>(
                    value: goal,
                    label: Text(goal.label),
                  ),
              ],
              selected: <NutritionGoal>{estimate.effectiveGoal},
              onSelectionChanged: (selection) => ref
                  .read(goalOverrideProvider.notifier)
                  .select(selection.first),
            ),
            const SizedBox(height: 24),
            Text('Activity Level', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final level in ActivityLevel.values)
                  ChoiceChip(
                    label: Text(level.label),
                    selected: level == activity,
                    onSelected: (_) =>
                        ref.read(activityLevelProvider.notifier).select(level),
                    backgroundColor: scheme.surface.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              activity.description,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Recommended Range',
                    style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatKcal(estimate.lowKcal)} - ${formatKcal(estimate.highKcal)}',
                    style: text.displaySmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text('kcal per day', style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Resting Energy:', style: text.bodyMedium),
                      Text('${formatKcal(estimate.bmr.round())} kcal', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('With Activity:', style: text.bodyMedium),
                      Text('${formatKcal(estimate.tdee.round())} kcal', style: text.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            if (estimate.floorApplied)
              const _Note(
                'We kept this at a safe minimum. Very low targets are not '
                'recommended.',
              ),
            if (estimate.weightLossRestricted)
              const _Note(
                'Weight-loss targets are not shown for under 18s, so this is '
                'a maintenance estimate.',
              ),
            const _Note(
              'This is a general estimate, not medical advice. Real needs '
              'vary from person to person.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 16,
            color: scheme.onSurfaceVariant,
            semanticLabel: 'Note',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
