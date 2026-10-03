import 'package:fitbuddy/features/schedule/data/time_block.dart';
import 'package:fitbuddy/features/schedule/widgets/block_type_ui.dart';
import 'package:flutter/material.dart';

/// What the editor sheet returns.
sealed class BlockEditorResult {
  const BlockEditorResult();
}

/// The user saved [block].
class BlockSaved extends BlockEditorResult {
  /// Creates the result.
  const BlockSaved(this.block);

  /// The edited or new block.
  final TimeBlock block;
}

/// The user deleted the block being edited.
class BlockDeleted extends BlockEditorResult {
  /// Creates the result.
  const BlockDeleted();
}

/// Opens the add/edit sheet. Returns null if dismissed.
Future<BlockEditorResult?> showBlockEditorSheet(
  BuildContext context, {
  TimeBlock? existing,
}) {
  return showModalBottomSheet<BlockEditorResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => BlockEditorSheet(existing: existing),
  );
}

/// Bottom sheet to add or edit a block: type, title, time, days of week.
class BlockEditorSheet extends StatefulWidget {
  /// Creates the sheet. [existing] is null when adding.
  const BlockEditorSheet({super.key, this.existing});

  /// Block being edited, or null for a new one.
  final TimeBlock? existing;

  @override
  State<BlockEditorSheet> createState() => _BlockEditorSheetState();
}

class _BlockEditorSheetState extends State<BlockEditorSheet> {
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late BlockType _type = widget.existing?.type ?? BlockType.workout;
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late int _minutes = widget.existing?.startMinutes ?? 7 * 60;
  late final Set<int> _days = {
    ...(widget.existing?.daysOfWeek ?? TimeBlock.allDays),
  };
  late bool _active = widget.existing?.isActive ?? true;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  TimeOfDay get _timeOfDay =>
      TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60);

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _timeOfDay);
    if (picked == null || !mounted) return;
    setState(() => _minutes = picked.hour * 60 + picked.minute);
  }

  void _save() {
    if (_days.isEmpty) {
      setState(() => _error = 'Pick at least one day.');
      return;
    }
    final typed = _title.text.trim();
    final e = widget.existing;
    Navigator.of(context).pop(
      BlockSaved(
        TimeBlock(
          id: e?.id ?? '',
          userId: e?.userId ?? '',
          type: _type,
          title: typed.isEmpty ? _type.label : typed,
          startMinutes: _minutes,
          daysOfWeek: _days.toList()..sort(),
          isActive: _active,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? 'New block' : 'Edit block',
              style: text.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Type', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in BlockType.values)
                  ChoiceChip(
                    avatar: Icon(t.icon, size: 18, semanticLabel: t.label),
                    label: Text(t.label),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            if (_type == BlockType.medicine)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reminder only. This app never gives dosage advice.',
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _type.label,
                border: const OutlineInputBorder(),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, semanticLabel: 'Time'),
              title: const Text('Time'),
              trailing: Text(
                _timeOfDay.format(context),
                style: text.titleMedium,
              ),
              onTap: _pickTime,
            ),
            Text('Repeat on', style: text.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_dayLabels[d - 1]),
                    selected: _days.contains(d),
                    onSelected: (on) => setState(() {
                      on ? _days.add(d) : _days.remove(d);
                      _error = null;
                    }),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: text.bodySmall?.copyWith(color: scheme.error),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(const BlockDeleted()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
