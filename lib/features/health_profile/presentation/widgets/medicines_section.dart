import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicine_edit_sheet.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Medicine reminders: name and times only.
class MedicinesSection extends ConsumerWidget {
  /// Creates the section.
  const MedicinesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final medicines = ref.watch(medicinesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text('Medicine reminders', style: text.titleMedium),
            ),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => showMedicineEditSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Reminders only. We never suggest doses or give medical advice.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AsyncValueView<List<Medicine>>(
          value: medicines,
          onRetry: () => ref.invalidate(medicinesProvider),
          builder: (list) => list.isEmpty
              ? const _EmptyMedicines()
              : Column(
                  children: <Widget>[
                    for (final medicine in list)
                      _MedicineTile(medicine: medicine),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.medication_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
              semanticLabel: 'No medicine reminders yet',
            ),
            const SizedBox(height: 8),
            Text(
              'No reminders yet. Tap Add to create one.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

enum _MedicineAction { edit, delete }

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
    final times =
        medicine.reminderTimes.map((t) => t.format(context)).join(', ');
    return Card(
      child: ListTile(
        minVerticalPadding: 12,
        onTap: () => showMedicineEditSheet(context, medicine: medicine),
        leading: const Icon(
          Icons.medication_outlined,
          semanticLabel: 'Medicine',
        ),
        title: Text(medicine.name),
        subtitle: Text(times),
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
                  case _MedicineAction.delete:
                    _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => const <PopupMenuEntry<_MedicineAction>>[
                PopupMenuItem<_MedicineAction>(
                  value: _MedicineAction.edit,
                  child: Text('Edit'),
                ),
                PopupMenuItem<_MedicineAction>(
                  value: _MedicineAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
