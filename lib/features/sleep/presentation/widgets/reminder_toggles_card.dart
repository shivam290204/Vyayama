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
                    color: const Color(0xFFFF9500)
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: Color(0xFFFF9500),
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
                    await NotificationService.instance.requestPermissions();
                  }
                  if (!context.mounted) return;
                  await runSafely(
                    context,
                    () => notifier.setWakeAlarm(on),
                  );
                  if (context.mounted) {
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

              // --- Detailed Alarm Settings (Shown when alarm is enabled) ---
              if (isAlarmOn) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E281E).withValues(alpha: 0.5)
                        : const Color(0xFFF4F7F2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Repeat Days
                      Text(
                        'Repeat on',
                        style: text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          final dayIndex = i + 1;
                          final isSelected =
                              settings.alarmDays.contains(dayIndex);
                          return FilterChip(
                            label: Text(_dayLabels[i]),
                            selected: isSelected,
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? const Color(0xFF142014)
                                  : scheme.onSurface,
                            ),
                            selectedColor: AppPalette.limeGreen,
                            backgroundColor: isDark
                                ? const Color(0xFF253325)
                                : Colors.white,
                            onSelected: (selected) {
                              final updated =
                                  List<int>.from(settings.alarmDays);
                              if (selected) {
                                if (!updated.contains(dayIndex)) {
                                  updated.add(dayIndex);
                                }
                              } else {
                                if (updated.length > 1) {
                                  updated.remove(dayIndex);
                                }
                              }
                              notifier.setAlarmDays(updated..sort());
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 14),

                      // Sound selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.music_note_rounded,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text('Alarm sound', style: text.bodyMedium),
                            ],
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _soundOptions.contains(settings.alarmSound)
                                  ? settings.alarmSound
                                  : _soundOptions.first,
                              borderRadius: BorderRadius.circular(14),
                              dropdownColor: isDark
                                  ? const Color(0xFF1E281E)
                                  : Colors.white,
                              style: text.bodyMedium?.copyWith(
                                color: AppPalette.limeGreen,
                                fontWeight: FontWeight.bold,
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
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Snooze Duration
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.snooze_rounded,
                                size: 18,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text('Snooze time', style: text.bodyMedium),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            children: _snoozeOptions.map((m) {
                              final isSelected = settings.snoozeMinutes == m;
                              return ChoiceChip(
                                label: Text('${m}m'),
                                selected: isSelected,
                                selectedColor: AppPalette.limeGreen,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? const Color(0xFF142014)
                                      : scheme.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (_) =>
                                    notifier.setSnoozeMinutes(m),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Vibrate toggle
                      SwitchListTile(
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
                      const SizedBox(height: 8),

                      // Test Alarm Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFF9500),
                            side: const BorderSide(
                              color: Color(0xFFFF9500),
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
              ],

              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              const SizedBox(height: 8),

              // --- Bedtime (Wind-down) Reminder Switch ---
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF818CF8)
                        .withValues(alpha: isDark ? 0.2 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bedtime_outlined,
                    color: Color(0xFF818CF8),
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
                onChanged: (v) => runSafely(
                  context,
                  () => notifier.setBedtimeReminder(v),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
