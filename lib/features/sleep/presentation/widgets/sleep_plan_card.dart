import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_format.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the suggested bedtime and wake-up time.
class SleepPlanCard extends ConsumerWidget {
  /// Creates the card.
  const SleepPlanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(sleepPlanProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bed = plan.bedtime.toTimeOfDay().format(context);
    final wake = plan.wakeTime.toTimeOfDay().format(context);
    final windDown = plan.windDownStart.toTimeOfDay().format(context);

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your suggested sleep plan',
              style: text.titleMedium
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Suggested bedtime $bed. Suggested wake up time $wake.',
              child: ExcludeSemantics(
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _TimeBlock(
                        icon: Icons.bedtime_outlined,
                        label: 'Bedtime',
                        value: bed,
                      ),
                    ),
                    Expanded(
                      child: _TimeBlock(
                        icon: Icons.wb_sunny_outlined,
                        label: 'Wake up',
                        value: wake,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'About ${formatSleepMinutes(plan.sleepMinutes)} of sleep. '
              'Start winding down around $windDown.',
              style: text.bodyMedium
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
            if (plan.isNightShift)
              _Notice(
                icon: Icons.nights_stay_outlined,
                message: 'Planned around your night shift, so sleep comes '
                    'after work.',
              ),
            for (final warning in plan.warnings)
              _Notice(
                icon: Icons.lightbulb_outline,
                message: _messageFor(warning),
              ),
          ],
        ),
      ),
    );
  }

  String _messageFor(SleepWarning warning) => switch (warning) {
        SleepWarning.shortEvening =>
          'Work ends close to bedtime. A lighter evening and a shorter '
              'wind-down can help.',
        SleepWarning.shortSleep =>
          'Your schedule leaves less than 7 hours for sleep. If you can, find '
              'a little extra time to rest.',
        SleepWarning.bedtimeDuringWork =>
          'This bedtime overlaps your work hours. Double-check the times '
              'above.',
      };
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: text.labelLarge?.copyWith(color: color)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: text.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
