import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/nutrition/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple daily water tracker in glasses.
class WaterTrackerCard extends ConsumerWidget {
  /// Creates the card.
  const WaterTrackerCard({super.key});

  Future<void> _change(BuildContext context, WidgetRef ref, int delta) async {
    try {
      await ref.read(waterProvider.notifier).change(delta);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final target = ref.watch(waterTargetGlassesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Water today', style: text.titleMedium),
            const SizedBox(height: 12),
            AsyncValueView<int>(
              value: ref.watch(waterProvider),
              onRetry: () => ref.invalidate(waterProvider),
              loadingHeight: 80,
              builder: (glasses) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton.filledTonal(
                        tooltip: 'Remove a glass',
                        onPressed:
                            glasses > 0 ? () => _change(context, ref, -1) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Expanded(
                        child: Semantics(
                          label: '$glasses of $target glasses',
                          child: Column(
                            children: <Widget>[
                              Text(
                                '$glasses / $target glasses',
                                style: text.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: LinearProgressIndicator(
                                  value: (glasses / target).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: 'Add a glass',
                        onPressed: () => _change(context, ref, 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    glasses >= target
                        ? 'Nice work, you reached your water goal today!'
                        : 'About 250 ml per glass. A general guide only.',
                    style: text.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
