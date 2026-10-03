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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Your daily calorie estimate', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add your age, height and weight in your profile to see an '
              'estimate.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => context.go(AppRoutes.profile),
              child: const Text('Open profile'),
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
    final goals = <NutritionGoal>[
      if (!isMinor) NutritionGoal.lose,
      NutritionGoal.maintain,
      NutritionGoal.gain,
    ];
    final range =
        '${formatKcal(estimate.lowKcal)} to ${formatKcal(estimate.highKcal)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Your daily calorie estimate', style: text.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<NutritionGoal>(
              style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
              showSelectedIcon: false,
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
            const SizedBox(height: 12),
            Text('How active are you?', style: text.labelLarge),
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
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              activity.description,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Estimated daily calories, $range kilocalories',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      range,
                      style: text.headlineMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('kcal per day (estimate)', style: text.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Resting energy about ${formatKcal(estimate.bmr.round())} kcal. '
              'With your activity about ${formatKcal(estimate.tdee.round())} '
              'kcal.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (estimate.floorApplied)
              _Note(
                'We kept this at a safe minimum. Very low targets are not '
                'recommended.',
              ),
            if (estimate.weightLossRestricted)
              _Note(
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
