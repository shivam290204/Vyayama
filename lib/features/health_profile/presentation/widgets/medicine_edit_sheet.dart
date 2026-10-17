import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
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
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
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
    AppSoundService.instance.stop();
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
      final exactAllowed =
          await NotificationService.instance.canScheduleExactAlarms();
      final notifAllowed =
          await NotificationService.instance.areNotificationsEnabled();
      if (!notifAllowed) {
        await NotificationService.instance.requestNotificationPermission();
      }

      // If exact alarm permission is not granted yet, save as inactive until permission is granted
      final shouldBeActive = exactAllowed && (base?.isActive ?? true);

      await ref.read(medicinesProvider.notifier).save(
            Medicine(
              id: base?.id ?? '',
              userId: base?.userId ?? '',
              name: name,
              reminderTimes: _times,
              isActive: shouldBeActive,
            ),
          );

      if (mounted) {
        Navigator.of(context).pop();
        final timesStr = _times.map((t) => t.format(context)).join(', ');
        if (shouldBeActive) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '💊 Reminder for $name set for $timesStr! You will get heads-up popups and alarms.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Open settings to guide user directly
          await NotificationService.instance.openExactAlarmSettings();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '💊 Reminder for $name saved! Please grant "Alarms & Reminders" in Settings to activate the alarm.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () =>
                    NotificationService.instance.openExactAlarmSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final isExact = msg.toLowerCase().contains('exact alarm') ||
          msg.toLowerCase().contains('alarms & reminders');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isNotEmpty ? msg : 'Could not save. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
          action: isExact
              ? SnackBarAction(
                  label: 'Settings',
                  onPressed: () =>
                      NotificationService.instance.openExactAlarmSettings(),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isEditing = widget.medicine != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A14) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3D2E) : const Color(0xFFDEE5DA),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Pill handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3B4D3B) : const Color(0xFFCCD5C7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit medicine reminder' : 'Add medicine reminder',
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      AppSoundService.instance.stop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Reminders only. This app does not give dosage or medical advice.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Alert Sound preview card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E281E).withValues(alpha: 0.6)
                      : const Color(0xFFF4F7F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE5A000).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A000).withValues(alpha: isDark ? 0.2 : 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alarm_on_rounded,
                        color: Color(0xFFE5A000),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Warning Alarm Sound',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Plays warning sound so you don\'t miss taking medicine.',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: AppSoundService.instance.isPlayingNotifier,
                      builder: (context, isPlaying, _) {
                        return TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFFE5A000),
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              AppSoundService.instance.stop();
                            } else {
                              AppSoundService.instance.playMedicineAlert();
                            }
                          },
                          icon: Icon(
                            isPlaying
                                ? Icons.stop_circle_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 18,
                          ),
                          label: Text(isPlaying ? 'Stop' : 'Preview'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Medicine name',
                  hintText: 'e.g., Vitamin D, Aspirin',
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 8),
              Text('Reminder times', style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
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
                      minimumSize: const Size(48, 44),
                    ),
                    onPressed: _addTime,
                    icon: const Icon(Icons.add_alarm, size: 18),
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
                      : const Text('Save reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
