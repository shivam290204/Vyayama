import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/safe_action.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_format.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the bedtime and wake-up time with interactive time pickers.
class SleepPlanCard extends ConsumerWidget {
  /// Creates the card.
  const SleepPlanCard({super.key});

  Future<void> _pickBedtime(BuildContext context, WidgetRef ref, TimeOfDay current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'SET BEDTIME',
    );
    if (picked == null || !context.mounted) return;
    await runSafely(
      context,
      () => ref.read(sleepSettingsProvider.notifier).setCustomBedtime(picked),
    );
  }

  Future<void> _pickWakeTime(BuildContext context, WidgetRef ref, TimeOfDay current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'SET WAKE-UP ALARM TIME',
    );
    if (picked == null || !context.mounted) return;
    await runSafely(
      context,
      () => ref.read(sleepSettingsProvider.notifier).setCustomWakeTime(picked),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(sleepPlanProvider);
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(sleepSettingsProvider.notifier);

    final bedTimeOfDay = plan.bedtime.toTimeOfDay();
    final wakeTimeOfDay = plan.wakeTime.toTimeOfDay();
    final bed = bedTimeOfDay.format(context);
    final wake = wakeTimeOfDay.format(context);
    final windDown = plan.windDownStart.toTimeOfDay().format(context);

    final isHealthyDuration = plan.sleepMinutes >= SleepPlanner.minSleepMinutes &&
        plan.sleepMinutes <= SleepPlanner.maxSleepMinutes;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _InteractiveTimeBlock(
                  icon: Icons.bedtime_outlined,
                  accentColor: const Color(0xFF818CF8),
                  label: 'Bedtime',
                  value: bed,
                  subtitle: plan.isCustom ? 'Custom · Tap to edit' : 'Tap to customize',
                  onTap: () => _pickBedtime(context, ref, bedTimeOfDay),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InteractiveTimeBlock(
                  icon: Icons.wb_sunny_outlined,
                  accentColor: const Color(0xFFFBBF24),
                  label: 'Wake up (Alarm)',
                  value: wake,
                  subtitle: plan.isCustom ? 'Custom · Tap to edit' : 'Tap to customize',
                  onTap: () => _pickWakeTime(context, ref, wakeTimeOfDay),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E281E).withValues(alpha: 0.6)
                  : const Color(0xFFF0F5EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHealthyDuration
                    ? AppPalette.forestGreen.withValues(alpha: 0.3)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHealthyDuration
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: isHealthyDuration ? AppPalette.limeGreen : const Color(0xFFF59E0B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatSleepMinutes(plan.sleepMinutes)} planned sleep. Wind-down starts at $windDown.',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (plan.isCustom) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => runSafely(context, notifier.resetToSuggested),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset to suggested schedule'),
              ),
            ),
          ],
          if (plan.isNightShift)
            const _Notice(
              icon: Icons.nights_stay_outlined,
              message: 'Planned around your night shift, so sleep comes after work.',
            ),
          for (final warning in plan.warnings)
            _Notice(
              icon: Icons.lightbulb_outline,
              message: _messageFor(warning),
            ),
        ],
      ),
    );
  }

  static String _messageFor(SleepWarning warning) => switch (warning) {
        SleepWarning.shortEvening =>
          'Work ends close to bedtime. A lighter evening and a shorter wind-down can help.',
        SleepWarning.shortSleep =>
          'Your schedule leaves less than 7 hours for sleep. If you can, find a little extra time to rest.',
        SleepWarning.bedtimeDuringWork =>
          'This bedtime overlaps your work hours. Double-check the times above.',
      };
}

class _InteractiveTimeBlock extends StatelessWidget {
  const _InteractiveTimeBlock({
    required this.icon,
    required this.accentColor,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E281E).withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: text.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: text.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: scheme.onTertiaryContainer,
              semanticLabel: 'Tip',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
