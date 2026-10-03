import 'package:fitbuddy/features/sleep/data/wind_down_items.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tick-off checklist of calming habits before bed.
class WindDownCard extends ConsumerWidget {
  /// Creates the card.
  const WindDownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final done = ref.watch(windDownProvider);
    final notifier = ref.read(windDownProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text('Wind-down checklist', style: text.titleMedium),
                ),
                if (done.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: notifier.reset,
                    child: const Text('Clear'),
                  ),
              ],
            ),
            Text(
              '${done.length} of ${kWindDownItems.length} done. Do what '
              'feels good tonight.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            for (final item in kWindDownItems)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(item.title),
                value: done.contains(item.id),
                onChanged: (_) => notifier.toggle(item.id),
              ),
          ],
        ),
      ),
    );
  }
}
