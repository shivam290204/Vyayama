import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/safe_action.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Switches for the bedtime reminder and the wake-up alarm.
class ReminderTogglesCard extends ConsumerWidget {
  /// Creates the card.
  const ReminderTogglesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final plan = ref.watch(sleepPlanProvider);
    final windDown = plan.windDownStart.toTimeOfDay().format(context);
    final wake = plan.wakeTime.toTimeOfDay().format(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Reminders', style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Reminders repeat every day. Please read the alarm tips below '
              'after turning them on.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            AsyncValueView<SleepSettings>(
              value: ref.watch(sleepSettingsProvider),
              onRetry: () => ref.invalidate(sleepSettingsProvider),
              loadingHeight: 100,
              builder: (settings) {
                final notifier = ref.read(sleepSettingsProvider.notifier);
                return Column(
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.bedtime_outlined,
                        semanticLabel: 'Bedtime reminder',
                      ),
                      title: const Text('Bedtime reminder'),
                      subtitle: Text('A wind-down nudge at $windDown'),
                      value: settings.bedtimeReminderOn,
                      onChanged: (v) => runSafely(
                        context,
                        () => notifier.setBedtimeReminder(v),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(
                        Icons.alarm,
                        semanticLabel: 'Wake-up alarm',
                      ),
                      title: const Text('Wake-up alarm'),
                      subtitle: Text('Alarm-style reminder at $wake'),
                      value: settings.wakeAlarmOn,
                      onChanged: (v) =>
                          runSafely(context, () => notifier.setWakeAlarm(v)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
