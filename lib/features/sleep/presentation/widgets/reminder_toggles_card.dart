import 'package:fitbuddy/core/widgets/glass_card.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final plan = ref.watch(sleepPlanProvider);
    final windDown = plan.windDownStart.toTimeOfDay().format(context);
    final wake = plan.wakeTime.toTimeOfDay().format(context);
    final isDark = scheme.brightness == Brightness.dark;

    return GlassCard(
      child: AsyncValueView<SleepSettings>(
        value: ref.watch(sleepSettingsProvider),
        onRetry: () => ref.invalidate(sleepSettingsProvider),
        loadingHeight: 100,
        builder: (settings) {
          final notifier = ref.read(sleepSettingsProvider.notifier);
          return Column(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bedtime_outlined,
                    color: scheme.primary,
                    semanticLabel: 'Bedtime reminder',
                    size: 22,
                  ),
                ),
                title: const Text('Bedtime reminder', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('A wind-down nudge at $windDown'),
                value: settings.bedtimeReminderOn,
                onChanged: (v) => runSafely(
                  context,
                  () => notifier.setBedtimeReminder(v),
                ),
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: isDark ? 0.15 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm,
                    color: scheme.secondary,
                    semanticLabel: 'Wake-up alarm',
                    size: 22,
                  ),
                ),
                title: const Text('Wake-up alarm', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Alarm-style reminder at $wake'),
                value: settings.wakeAlarmOn,
                onChanged: (v) =>
                    runSafely(context, () => notifier.setWakeAlarm(v)),
              ),
            ],
          );
        },
      ),
    );
  }
}
