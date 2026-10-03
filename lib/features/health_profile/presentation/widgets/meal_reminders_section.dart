import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Meal reminder times: breakfast, lunch, snack and dinner.
class MealRemindersSection extends ConsumerWidget {
  /// Creates the section.
  const MealRemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final meals = ref.watch(mealRemindersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Meal reminders', style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tap a meal to change its time. Reminders repeat every day.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AsyncValueView<MealReminderSettings>(
          value: meals,
          onRetry: () => ref.invalidate(mealRemindersProvider),
          builder: (settings) => Card(
            child: Column(
              children: <Widget>[
                for (final slot in MealSlot.values)
                  _MealRow(slot: slot, reminder: settings.of(slot)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MealRow extends ConsumerWidget {
  const _MealRow({required this.slot, required this.reminder});

  final MealSlot slot;
  final MealReminder reminder;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: reminder.time,
    );
    if (picked == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(mealRemindersProvider.notifier).updateSlot(slot, time: picked),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      minVerticalPadding: 8,
      onTap: () => _pickTime(context, ref),
      leading: Icon(_iconFor(slot), semanticLabel: slot.label),
      title: Text(slot.label),
      subtitle: Text(reminder.time.format(context)),
      trailing: Semantics(
        label: '${slot.label} reminder',
        child: Switch(
          value: reminder.enabled,
          onChanged: (value) => _run(
            context,
            () => ref
                .read(mealRemindersProvider.notifier)
                .updateSlot(slot, enabled: value),
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => Icons.free_breakfast_outlined,
      MealSlot.lunch => Icons.lunch_dining_outlined,
      MealSlot.snack => Icons.bakery_dining_outlined,
      MealSlot.dinner => Icons.dinner_dining_outlined,
    };
