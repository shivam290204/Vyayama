import 'package:fitbuddy/core/widgets/glass_card.dart';
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

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${done.length} of ${kWindDownItems.length} done. Do what '
                  'feels good tonight.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              if (done.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: notifier.reset,
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in kWindDownItems)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              value: done.contains(item.id),
              onChanged: (_) => notifier.toggle(item.id),
            ),
        ],
      ),
    );
  }
}
