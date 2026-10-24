import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/alarm_test_dialog.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/safe_action.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full interactive alarm & bedtime reminder settings card.
class ReminderTogglesCard extends ConsumerWidget {
  /// Creates the card.
  const ReminderTogglesCard({super.key});

  static const List<String> _soundOptions = [
    'Gentle Chime',
    'Morning Breeze',
    'Energy Rise',
    'Classic Bell',
  ];

  static const List<int> _snoozeOptions = [5, 10, 15];

  static const List<String> _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final plan = ref.watch(sleepPlanProvider);
    final windDown = plan.windDownStart.toTimeOfDay().format(context);
    final wake = plan.wakeTime.toTimeOfDay().format(context);
    final isDark = scheme.brightness == Brightness.dark;

    return GlassCard(
      child: AsyncValueView<SleepSettings>(
        value: ref.watch(sleepSettingsProvider),
        onRetry: () => ref.invalidate(sleepSettingsProvider),
        loadingHeight: 120,
        builder: (settings) {
          final notifier = ref.read(sleepSettingsProvider.notifier);
          final isAlarmOn = settings.wakeAlarmOn == true;
          final isBedtimeReminderOn = settings.bedtimeReminderOn == true;
          final isVibrate = settings.vibrate == true;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // --- Wake-up Alarm Master Switch ---
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.streak
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm_on_rounded,
                    color: context.colors.streak,
                    semanticLabel: 'Wake-up alarm',
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Wake-up alarm',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                subtitle: Text(
                  isAlarmOn
                      ? 'Alarm set for $wake'
                      : 'Rings at $wake when active',
                  style: TextStyle(
                    color: isAlarmOn
                        ? AppPalette.limeGreen
                        : scheme.onSurfaceVariant,
                    fontWeight: isAlarmOn
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                value: isAlarmOn,
                onChanged: (on) async {
                  if (on) {
                    final notifAllowed =
                        await NotificationService.instance.areNotificationsEnabled();
                    if (!notifAllowed) {
                      await NotificationService.instance.requestNotificationPermission();
                    }
                    final exactAllowed =
                        await NotificationService.instance.canScheduleExactAlarms();
                    if (!exactAllowed) {
                      await NotificationService.instance.openExactAlarmSettings();
                    }
                    final channelActive = await NotificationService.instance
                        .isChannelEnabled(NotificationService.wakeAlarmChannelId);
                    if (!channelActive && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Wake Alarms channel is muted/disabled in system settings. Please unmute it to hear alarms.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                  if (!context.mounted) return;
                  final ok = await runSafely(
                    context,
                    () => notifier.setWakeAlarm(on),
                  );
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          on
                              ? 'Wake-up alarm scheduled for $wake daily! ⏰'
                              : 'Wake-up alarm turned off.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),

              // --- Detailed Alarm Settings (Always accessible) ---
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainer.withValues(alpha: isAlarmOn ? 0.6 : 0.3)
                      : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isAlarmOn
                        ? context.colors.streak.withValues(alpha: 0.45)
                        : scheme.outlineVariant,
                    width: isAlarmOn ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                isAlarmOn
                                    ? Icons.alarm_on_rounded
                                    : Icons.alarm_off_rounded,
                                size: 16,
                                color: isAlarmOn
                                    ? context.colors.streak
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isAlarmOn
                                      ? 'Alarm Scheduled ($wake)'
                                      : 'Alarm Inactive (Off)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isAlarmOn
                                        ? context.colors.streak
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isAlarmOn)
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppPalette.limeGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () async {
                              final notifAllowed =
                                  await NotificationService.instance.areNotificationsEnabled();
                              if (!notifAllowed) {
                                await NotificationService.instance.requestNotificationPermission();
                              }
                              final exactAllowed =
                                  await NotificationService.instance.canScheduleExactAlarms();
                              if (!exactAllowed) {
                                await NotificationService.instance.openExactAlarmSettings();
                              }
                              if (!context.mounted) return;
                              await runSafely(context, () => notifier.setWakeAlarm(true));
                            },
                            child: const Text(
                              'Enable Alarm',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Repeat Days
                    Text(
                      'Repeat on',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(7, (i) {
                        final dayIndex = i + 1;
                        final isSelected =
                            settings.alarmDays.contains(dayIndex);
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.5),
                            child: InkWell(
                              onTap: () {
                                final updated =
                                    List<int>.from(settings.alarmDays);
                                if (isSelected) {
                                  if (updated.length > 1) {
                                    updated.remove(dayIndex);
                                  }
                                } else {
                                  if (!updated.contains(dayIndex)) {
                                    updated.add(dayIndex);
                                  }
                                }
                                notifier.setAlarmDays(updated..sort());
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppPalette.limeGreen
                                      : scheme.surfaceContainerHigh,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppPalette.limeGreen
                                        : scheme.outlineVariant,
                                    width: 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppPalette.limeGreen
                                                .withValues(alpha: 0.35),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  _dayLabels[i],
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? scheme.onTertiary
                                        : (isDark
                                            ? Colors.white70
                                            : scheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),

                    // Sound selection with Preview Button
                    Row(
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alarm sound',
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 10, right: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? scheme.surfaceContainerHigh
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: scheme.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isDense: true,
                                  value: _soundOptions
                                          .contains(settings.alarmSound)
                                      ? settings.alarmSound
                                      : _soundOptions.first,
                                  borderRadius: BorderRadius.circular(14),
                                  dropdownColor: isDark
                                      ? scheme.surfaceContainer
                                      : Colors.white,
                                  style: text.bodyMedium?.copyWith(
                                    color: AppPalette.limeGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  items: _soundOptions
                                      .map(
                                        (s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (sound) {
                                    if (sound != null) {
                                      notifier.setAlarmSound(sound);
                                      AppSoundService.instance.playWakeUpAlarm();
                                    }
                                  },
                                ),
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    AppSoundService.instance.isPlayingNotifier,
                                builder: (context, isPlaying, _) {
                                  return IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                    tooltip: isPlaying
                                        ? 'Stop preview'
                                        : 'Preview alarm sound',
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.stop_circle_rounded
                                          : Icons.play_circle_fill_rounded,
                                      color: context.colors.streak,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      if (isPlaying) {
                                        AppSoundService.instance.stop();
                                      } else {
                                        AppSoundService.instance.playWakeUpAlarm();
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Snooze Duration
                    Row(
                      children: [
                        Icon(
                          Icons.snooze_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Snooze time',
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _snoozeOptions.map((m) {
                            final isSelected = settings.snoozeMinutes == m;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: InkWell(
                                onTap: () => notifier.setSnoozeMinutes(m),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppPalette.limeGreen
                                        : (isDark
                                            ? scheme.surfaceContainerHigh
                                            : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppPalette.limeGreen
                                          : scheme.outlineVariant,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${m}m',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? scheme.onTertiary
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Vibrate toggle
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Vibrate on alarm'),
                        secondary: Icon(
                          Icons.vibration_rounded,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        value: isVibrate,
                        onChanged: notifier.setVibrate,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Test Alarm Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.streak,
                          side: BorderSide(
                            color: context.colors.streak,
                            width: 1.2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          AlarmTestDialog.show(
                            context,
                            alarmTime: wake,
                            alarmSound: settings.alarmSound,
                            vibrate: isVibrate,
                            snoozeMinutes: settings.snoozeMinutes,
                          );
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded,
                            size: 18),
                        label: const Text(
                          'Test Alarm Now',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              const SizedBox(height: 8),

              // --- Bedtime (Wind-down) Reminder Switch ---
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.sleep
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bedtime_outlined,
                    color: context.colors.sleep,
                    semanticLabel: 'Bedtime reminder',
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Bedtime reminder',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                subtitle: Text(
                  'A calming wind-down nudge at $windDown (1h before bed)',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                value: isBedtimeReminderOn,
                onChanged: (v) async {
                  if (v) {
                    final notifAllowed =
                        await NotificationService.instance.areNotificationsEnabled();
                    if (!notifAllowed) {
                      await NotificationService.instance.requestNotificationPermission();
                    }
                  }
                  if (!context.mounted) return;
                  final ok = await runSafely(
                    context,
                    () => notifier.setBedtimeReminder(v),
                  );
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          v
                              ? 'Bedtime reminder scheduled for $windDown daily! 🌙'
                              : 'Bedtime reminder turned off.',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
