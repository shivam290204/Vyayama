import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/data/time_codec.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens the add/edit sheet. Pass [medicine] to edit an existing one.
Future<void> showMedicineEditSheet(
  BuildContext context, {
  Medicine? medicine,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => MedicineEditSheet(medicine: medicine),
  );
}

/// Bottom sheet to add or edit a medicine: name and reminder times only.
class MedicineEditSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const MedicineEditSheet({super.key, this.medicine});

  /// Medicine being edited, or null when adding.
  final Medicine? medicine;

  @override
  ConsumerState<MedicineEditSheet> createState() => _MedicineEditSheetState();
}

class _MedicineEditSheetState extends ConsumerState<MedicineEditSheet> {
  late final TextEditingController _name;
  late List<TimeOfDay> _times;
  String? _nameError;
  String? _timesError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.medicine?.name ?? '');
    _times = <TimeOfDay>[...?widget.medicine?.reminderTimes];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null || !mounted) return;
    if (_times.any((t) => minutesOfDay(t) == minutesOfDay(picked))) return;
    setState(() {
      _times = <TimeOfDay>[..._times, picked]..sort(compareTimes);
      _timesError = null;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final nameError = name.isEmpty ? 'Please enter a name' : null;
    final timesError = _times.isEmpty ? 'Add at least one reminder time' : null;
    if (nameError != null || timesError != null) {
      setState(() {
        _nameError = nameError;
        _timesError = timesError;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final base = widget.medicine;
      await ref.read(medicinesProvider.notifier).save(
            Medicine(
              id: base?.id ?? '',
              userId: base?.userId ?? '',
              name: name,
              reminderTimes: _times,
              isActive: base?.isActive ?? true,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isEditing = widget.medicine != null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isEditing ? 'Edit medicine reminder' : 'Add medicine reminder',
            style: text.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Reminders only. This app does not give dosage or medical advice.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Medicine name',
              errorText: _nameError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 8),
          Text('Reminder times', style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final time in _times)
                InputChip(
                  label: Text(time.format(context)),
                  deleteButtonTooltipMessage:
                      'Remove ${time.format(context)}',
                  onDeleted: () => setState(() => _times.remove(time)),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: _addTime,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Add time'),
              ),
            ],
          ),
          if (_timesError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _timesError!,
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
