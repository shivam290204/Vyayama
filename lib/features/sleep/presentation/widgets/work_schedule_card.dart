import 'package:fitbuddy/core/widgets/glass_card.dart';
import 'package:fitbuddy/features/health_profile/presentation/widgets/async_value_view.dart';
import 'package:fitbuddy/features/sleep/data/sleep_settings.dart';
import 'package:fitbuddy/features/sleep/domain/sleep_planner.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/safe_action.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_format.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Work hours, goal and sleep length inputs for the sleep plan.
class WorkScheduleCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const WorkScheduleCard({super.key});

  @override
  ConsumerState<WorkScheduleCard> createState() => _WorkScheduleCardState();
}

class _WorkScheduleCardState extends ConsumerState<WorkScheduleCard> {
  double? _dragMinutes;

  Future<void> _pick(
    BuildContext context,
    TimeOfDay initial,
    Future<void> Function(TimeOfDay) onPicked,
  ) async {
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !context.mounted) return;
    await runSafely(context, () => onPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      child: AsyncValueView<SleepSettings>(
        value: ref.watch(sleepSettingsProvider),
        onRetry: () => ref.invalidate(sleepSettingsProvider),
        builder: (_) {
          final inputs = ref.watch(sleepInputsProvider);
          final notifier = ref.read(sleepSettingsProvider.notifier);
          final plannedMinutes = inputs.sleepMinutes
              .clamp(
                SleepPlanner.minSleepMinutes,
                SleepPlanner.maxSleepMinutes,
              )
              .toInt();
          final effectiveMinutes = _dragMinutes?.round() ?? plannedMinutes;
          final isCustom = inputs.isCustomLength || _dragMinutes != null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.work_outline,
                  semanticLabel: 'Work start',
                ),
                title: const Text('Work starts'),
                trailing: Text(
                  inputs.workStart.format(context),
                  style: text.titleMedium,
                ),
                onTap: () => _pick(
                  context,
                  inputs.workStart,
                  notifier.setWorkStart,
                ),
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.home_work_outlined,
                  semanticLabel: 'Work end',
                ),
                title: const Text('Work ends'),
                trailing: Text(
                  inputs.workEnd.format(context),
                  style: text.titleMedium,
                ),
                onTap: () => _pick(
                  context,
                  inputs.workEnd,
                  notifier.setWorkEnd,
                ),
              ),
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.2)),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.flag_outlined,
                  semanticLabel: 'Goal',
                ),
                title: const Text('Your goal'),
                subtitle: const Text('Taken from your profile'),
                trailing: Text(
                  goalLabel(inputs.goal),
                  style: text.titleMedium,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Sleep length: ${formatSleepMinutes(effectiveMinutes)}',
                      style: text.titleSmall,
                    ),
                  ),
                  if (isCustom)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        setState(() {
                          _dragMinutes = null;
                        });
                        runSafely(
                          context,
                          () => notifier.setSleepMinutes(null),
                        );
                      },
                      child: const Text('Use suggested'),
                    ),
                ],
              ),
              Slider(
                value: effectiveMinutes.toDouble(),
                min: SleepPlanner.minSleepMinutes.toDouble(),
                max: SleepPlanner.maxSleepMinutes.toDouble(),
                divisions: 4,
                label: formatSleepMinutes(effectiveMinutes),
                semanticFormatterCallback: (v) =>
                    formatSleepMinutes(v.round()),
                onChanged: (v) {
                  setState(() {
                    _dragMinutes = v;
                  });
                },
                onChangeEnd: (v) {
                  setState(() {
                    _dragMinutes = null;
                  });
                  runSafely(
                    context,
                    () => notifier.setSleepMinutes(v.round()),
                  );
                },
              ),
              Text(
                'Many adults feel best with 7 to 9 hours. This is a general guide.',
                style: text.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }
}
