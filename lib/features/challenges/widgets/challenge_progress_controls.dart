import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/features/challenges/data/challenge.dart';
import 'package:fitbuddy/features/challenges/providers.dart';
import 'package:fitbuddy/features/schedule/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final ButtonStyle _bigIconButton =
    IconButton.styleFrom(minimumSize: const Size.square(48));

/// The right controls for today's [challenge], depending on its type.
class ChallengeProgressControls extends ConsumerWidget {
  /// Creates the controls.
  const ChallengeProgressControls({super.key, required this.challenge});

  /// Today's challenge.
  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    switch (challenge.type) {
      case ChallengeType.steps:
      case ChallengeType.activeMinutes:
        return Row(
          children: [
            const Icon(Icons.sync, size: 20, semanticLabel: 'Automatic'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tracked automatically from your activity.',
                style: text.bodyMedium,
              ),
            ),
          ],
        );
      case ChallengeType.workout:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => context.push(AppRoutes.workouts),
            icon: const Icon(Icons.fitness_center),
            label: const Text('Open workouts'),
          ),
        );
      case ChallengeType.checkoff:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () =>
                ref.read(manualProgressProvider.notifier).change(1),
            icon: const Icon(Icons.check),
            label: const Text('Mark done'),
          ),
        );
      case ChallengeType.reps:
      case ChallengeType.water:
      case ChallengeType.count:
        final step = progressStepFor(challenge);
        final value = ref.watch(todayProgressProvider);
        final notifier = ref.read(manualProgressProvider.notifier);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: 'Remove $step',
              style: _bigIconButton,
              onPressed: value > 0 ? () => notifier.change(-step) : null,
              icon: const Icon(Icons.remove),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatInt(value), style: text.headlineMedium),
                  Text(challenge.type.unit, style: text.bodySmall),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: 'Add $step',
              style: _bigIconButton,
              onPressed: () => notifier.change(step),
              icon: const Icon(Icons.add),
            ),
          ],
        );
    }
  }
}
