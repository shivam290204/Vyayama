import 'package:fitbuddy/core/router/app_routes.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/medicine_edit_sheet.dart';
import 'package:fitbuddy/features/health_profile/providers.dart';
import 'package:fitbuddy/features/schedule/widgets/medicine_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

/// Medicine reminders: name and times only.
class MedicinesSection extends ConsumerStatefulWidget {
  /// Creates the section.
  const MedicinesSection({super.key});

  @override
  ConsumerState<MedicinesSection> createState() => _MedicinesSectionState();
}

class _MedicinesSectionState extends ConsumerState<MedicinesSection>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _exactAlarmsEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final notif =
        await NotificationService.instance.areNotificationsEnabled();
    final exact =
        await NotificationService.instance.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _notificationsEnabled = notif;
        _exactAlarmsEnabled = exact;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!_notificationsEnabled) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5A000)
                  .withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE5A000).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A000).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off_rounded,
                        color: Color(0xFFE5A000),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notifications are turned off',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF8A5A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To receive heads-up popups and loud warning alarms when it is time to take your medicine, please enable notifications.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF5A4A20),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A000),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final granted =
                        await NotificationService.instance.requestPermissions();
                    if (!granted) {
                      await openAppSettings();
                    }
                    await _checkPermissions();
                  },
                  icon: const Icon(Icons.notifications_active_rounded, size: 18),
                  label: const Text(
                    'Enable Notifications',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ] else if (!_exactAlarmsEnabled) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500)
                  .withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF9500).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alarm_off_rounded,
                        color: Color(0xFFFF9500),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Alarms & Reminders permission needed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF8A5A00),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To ring loud alarms and show popups when the app is closed, Android requires "Alarms & Reminders" permission.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF5A4A20),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await NotificationService.instance.openExactAlarmSettings();
                    await _checkPermissions();
                  },
                  icon: const Icon(Icons.alarm_on_rounded, size: 18),
                  label: const Text(
                    'Grant Alarm Permission',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
        AsyncValueView<List<Medicine>>(
          value: medicines,
          onRetry: () => ref.invalidate(medicinesProvider),
          builder: (list) => list.isEmpty
              ? _EmptyMedicines(onCheckPermissions: _checkPermissions)
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF9500),
                            side: const BorderSide(color: Color(0xFFFF9500)),
                          ),
                          onPressed: () =>
                              context.push(AppRoutes.notificationDiagnostics),
                          icon: const Icon(Icons.healing_rounded, size: 16),
                          label: const Text(
                            'Diagnostics',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE5A000),
                            side: const BorderSide(color: Color(0xFFE5A000)),
                          ),
                          onPressed: () async {
                            final timeStr = list.first.reminderTimes.firstOrNull
                                    ?.format(context) ??
                                '09:00 AM';
                            await NotificationService.instance
                                .requestPermissions();
                            await NotificationService.instance
                                .scheduleTestAlarmInSeconds(
                              id: 9992,
                              seconds: 5,
                              title: '💊 Medicine Reminder (Test)',
                              body: 'Time to take ${list.first.name} ($timeStr)',
                              channelId: NotificationService.medicineChannelId,
                              channelName: 'Medicine Reminders',
                              alarmStyle: true,
                              payload:
                                  'medicine:test:Medicine reminder:Reminder: ${list.first.name}',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Alarm set for 5s! Lock phone to test heads-up popup and alarm sound 🔔💊',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.timer_outlined, size: 16),
                          label: const Text(
                            '5s Lock Test',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE5A000),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () async {
                            await NotificationService.instance
                                .requestPermissions();
                            if (context.mounted) {
                              MedicineAlertDialog.show(
                                context,
                                medicineName: list.first.name,
                                time: list.first.reminderTimes.firstOrNull
                                        ?.format(context) ??
                                    '09:00 AM',
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.play_circle_fill_rounded,
                            size: 16,
                          ),
                          label: const Text(
                            'Test Alert Popup',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyMedicines extends StatelessWidget {
  const _EmptyMedicines({this.onCheckPermissions});

  final VoidCallback? onCheckPermissions;

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
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await NotificationService.instance.requestPermissions();
                    onCheckPermissions?.call();
                    if (context.mounted) showMedicineEditSheet(context);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add reminder'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await NotificationService.instance.requestPermissions();
                    onCheckPermissions?.call();
                    if (context.mounted) {
                      MedicineAlertDialog.show(
                        context,
                        medicineName: 'Daily Vitamin',
                        time: '09:00 AM',
                      );
                    }
                  },
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Test alert sound'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE5A000),
              ),
              onPressed: () async {
                await NotificationService.instance.requestPermissions();
                onCheckPermissions?.call();
                await NotificationService.instance.scheduleTestAlarmInSeconds(
                  id: 9991,
                  seconds: 5,
                  title: '💊 Medicine Reminder (Test)',
                  body: 'Time to take your scheduled medicine!',
                  channelId: NotificationService.medicineChannelId,
                  channelName: 'Medicine Reminders',
                  alarmStyle: true,
                  payload:
                      'medicine:test:Medicine reminder:Reminder: Daily Medicine',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Alarm set for 5 seconds from now! Lock your phone to test the heads-up popup and alarm sound 🔔💊',
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.timer_outlined, size: 16),
              label: const Text(
                'Test 5s Alarm (Lock phone to test)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF9500),
              ),
              onPressed: () => context.push(AppRoutes.notificationDiagnostics),
              icon: const Icon(Icons.healing_rounded, size: 16),
              label: const Text(
                'Alarm & Notification Diagnostics',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
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

  void _showError(BuildContext context, [Object? error]) {
    final msg =
        error?.toString().replaceFirst(RegExp(r'^Exception:\s*'), '') ?? '';
    final isExact = msg.toLowerCase().contains('exact alarm') ||
        msg.toLowerCase().contains('alarms & reminders');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg.isNotEmpty ? msg : 'Something went wrong. Please try again.',
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

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    if (value) {
      final notifAllowed =
          await NotificationService.instance.areNotificationsEnabled();
      if (!notifAllowed) {
        await NotificationService.instance.requestNotificationPermission();
      }
      final exactAllowed =
          await NotificationService.instance.canScheduleExactAlarms();
      if (!exactAllowed) {
        await NotificationService.instance.openExactAlarmSettings();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please grant "Alarms & Reminders" permission in Settings to turn on medicine alarms.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () =>
                    NotificationService.instance.openExactAlarmSettings(),
              ),
            ),
          );
        }
        return;
      }
    }
    try {
      await ref.read(medicinesProvider.notifier).setActive(medicine, value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '💊 Alarms active for ${medicine.name}!'
                  : 'Alarm turned off for ${medicine.name}.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) _showError(context, e);
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
