import 'package:fitbuddy/core/widgets/glass_card.dart';
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
    final medicines = ref.watch(medicinesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[

        AsyncValueView<List<Medicine>>(
          value: medicines,
          onRetry: () => ref.invalidate(medicinesProvider),
          builder: (list) => list.isEmpty
              ? const _EmptyMedicines()
              : GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < list.length; i++) ...[
                        _MedicineTile(medicine: list[i]),
                        if (i < list.length - 1)
                          Divider(height: 1, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                      ],
                    ],
                  ),
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
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
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
                size: 48,
                color: scheme.primary,
                semanticLabel: 'No medicine reminders yet',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No reminders yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the Add button to create your first medicine reminder.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
    );
  }
}
