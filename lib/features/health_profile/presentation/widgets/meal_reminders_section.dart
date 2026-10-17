import 'package:fitbuddy/core/widgets/glass_card.dart';
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
    final meals = ref.watch(mealRemindersProvider);

    return AsyncValueView<MealReminderSettings>(
      value: meals,
      onRetry: () => ref.invalidate(mealRemindersProvider),
      builder: (settings) => GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            for (var i = 0; i < MealSlot.values.length; i++) ...[
              _MealRow(
                slot: MealSlot.values[i],
                reminder: settings.of(MealSlot.values[i]),
              ),
              if (i < MealSlot.values.length - 1)
                Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            ],
          ],
        ),
      ),
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
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isNotEmpty ? msg : 'Could not save. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return ListTile(
      minVerticalPadding: 16,
      onTap: () => _pickTime(context, ref),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          _iconFor(slot),
          color: scheme.primary,
          semanticLabel: slot.label,
          size: 22,
        ),
      ),
      title: Text(
        slot.label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(reminder.time.format(context)),
      ),
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
