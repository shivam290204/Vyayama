import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitbuddy/core/theme/app_spacing.dart';
import 'package:fitbuddy/features/onboarding/providers.dart';
import 'package:fitbuddy/features/onboarding/widgets/step_scaffold.dart';

/// Optional wake, bedtime and work times (used for the sleep plan).
class ScheduleStep extends ConsumerWidget {
  const ScheduleStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return StepScaffold(
      title: 'Your daily schedule',
      subtitle: 'Optional. We use it to suggest a sleep routine and good workout times.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TimeTile(
            icon: Icons.wb_sunny_outlined,
            label: 'Wake up',
            time: draft.wakeTime,
            fallback: const TimeOfDay(hour: 7, minute: 0),
            onPicked: (t) => notifier.setSchedule(wake: t),
          ),
          _TimeTile(
            icon: Icons.bedtime_outlined,
            label: 'Bedtime',
            time: draft.sleepTime,
            fallback: const TimeOfDay(hour: 23, minute: 0),
            onPicked: (t) => notifier.setSchedule(sleep: t),
          ),
          _TimeTile(
            icon: Icons.work_outline_rounded,
            label: 'Work starts',
            time: draft.workStart,
            fallback: const TimeOfDay(hour: 9, minute: 0),
            onPicked: (t) => notifier.setSchedule(workStart: t),
          ),
          _TimeTile(
            icon: Icons.work_off_outlined,
            label: 'Work ends',
            time: draft.workEnd,
            fallback: const TimeOfDay(hour: 17, minute: 0),
            onPicked: (t) => notifier.setSchedule(workEnd: t),
          ),
          if (draft.hasSchedule)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: notifier.clearSchedule,
                child: const Text('Clear times'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.time,
    required this.fallback,
    required this.onPicked,
  });

  final IconData icon;
  final String label;
  final TimeOfDay? time;
  final TimeOfDay fallback;
  final ValueChanged<TimeOfDay> onPicked;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: time ?? fallback,
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = time?.format(context) ?? 'Not set';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: ListTile(
          minVerticalPadding: AppSpacing.md,
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: time == null ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _pick(context),
        ),
      ),
    );
  }
}
