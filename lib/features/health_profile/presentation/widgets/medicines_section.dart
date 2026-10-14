import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicine_edit_sheet.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/schedule/widgets/medicine_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medicine reminders: name and times only.
class MedicinesSection extends ConsumerWidget {
  /// Creates the section.
  const MedicinesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicines = ref.watch(medicinesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AsyncValueView<List<Medicine>>(
          value: medicines,
          onRetry: () => ref.invalidate(medicinesProvider),
          builder: (list) => list.isEmpty
              ? const _EmptyMedicines()
              : Column(
                  children: [
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: <Widget>[
                          for (var i = 0; i < list.length; i++) ...[
                            _MedicineTile(medicine: list[i]),
                            if (i < list.length - 1)
                              Divider(
                                height: 1,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.2),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE5A000),
                        ),
                        onPressed: () => MedicineAlertDialog.show(
                          context,
                          medicineName: list.first.name,
                          time: list.first.reminderTimes.firstOrNull
                                  ?.format(context) ??
                              '09:00 AM',
                        ),
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Test Medicine Alert Sound',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyMedicines extends StatelessWidget {
  const _EmptyMedicines();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication_outlined,
                size: 44,
                color: scheme.primary,
                semanticLabel: 'No medicine reminders yet',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No reminders yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add reminders for your vitamins or medicines so you stay consistent daily.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => showMedicineEditSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add reminder'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => MedicineAlertDialog.show(
                    context,
                    medicineName: 'Daily Vitamin',
                    time: '09:00 AM',
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Test alert sound'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _MedicineAction { edit, testAlert, delete }

class _MedicineTile extends ConsumerWidget {
  const _MedicineTile({required this.medicine});

  final Medicine medicine;

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Something went wrong. Please try again.')),
    );
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      await ref.read(medicinesProvider.notifier).setActive(medicine, value);
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete reminder?'),
        content: Text('Remove all reminders for ${medicine.name}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(medicinesProvider.notifier).delete(medicine);
    } catch (_) {
      if (context.mounted) _showError(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final times =
        medicine.reminderTimes.map((t) => t.format(context)).join(', ');

    return ListTile(
      minVerticalPadding: 16,
      onTap: () => showMedicineEditSheet(context, medicine: medicine),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.secondary.withValues(alpha: isDark ? 0.15 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.medication_outlined,
          color: scheme.secondary,
          semanticLabel: 'Medicine',
          size: 22,
        ),
      ),
      title: Text(
        medicine.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(times),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: 'Reminders for ${medicine.name}',
            child: Switch(
              value: medicine.isActive,
              onChanged: (v) => _setActive(context, ref, v),
            ),
          ),
          PopupMenuButton<_MedicineAction>(
            tooltip: 'More options',
            onSelected: (action) {
              switch (action) {
                case _MedicineAction.edit:
                  showMedicineEditSheet(context, medicine: medicine);
                case _MedicineAction.testAlert:
                  MedicineAlertDialog.show(
                    context,
                    medicineName: medicine.name,
                    time: medicine.reminderTimes.firstOrNull?.format(context) ??
                        '09:00 AM',
                  );
                case _MedicineAction.delete:
                  _confirmDelete(context, ref);
              }
            },
            itemBuilder: (_) => const <PopupMenuEntry<_MedicineAction>>[
              PopupMenuItem<_MedicineAction>(
                value: _MedicineAction.edit,
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem<_MedicineAction>(
                value: _MedicineAction.testAlert,
                child: Row(
                  children: [
                    Icon(Icons.volume_up_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Test alert sound'),
                  ],
                ),
              ),
              PopupMenuItem<_MedicineAction>(
                value: _MedicineAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
