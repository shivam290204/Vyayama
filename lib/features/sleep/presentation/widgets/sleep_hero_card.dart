import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:fitbuddy/features/sleep/data/day_time_convert.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/alarm_test_dialog.dart';
import 'package:fitbuddy/features/sleep/presentation/widgets/sleep_format.dart';
import 'package:fitbuddy/features/sleep/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Top hero card on SleepScreen featuring the 3D sleeping mascot and quick status.
class SleepHeroCard extends ConsumerWidget {
  const SleepHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(sleepPlanProvider);
    final settings = ref.watch(sleepSettingsProvider).asData?.value;
    final wake = plan.wakeTime.toTimeOfDay().format(context);
    final bed = plan.bedtime.toTimeOfDay().format(context);
    final durationStr = formatSleepMinutes(plan.sleepMinutes);
    final isAlarmOn = settings?.wakeAlarmOn == true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF141A14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAlarmOn
              ? const Color(0xFFFF9500).withValues(alpha: 0.35)
              : const Color(0xFF2E3D2E),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          if (isAlarmOn)
            BoxShadow(
              color: const Color(0xFFFF9500).withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient subtle radial gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.centerRight,
                    radius: 1.1,
                    colors: [
                      const Color(0xFF1F2B1F).withValues(alpha: 0.6),
                      const Color(0xFF141A14),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mascot Banner Image
                SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/mascot/sleeping.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      // Gradient overlay to fade smoothly into the text
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF141A14).withValues(alpha: 0.85),
                            ],
                            stops: const [0.55, 1.0],
                          ),
                        ),
                      ),
                      // Active Alarm Badge
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isAlarmOn
                                ? const Color(0xFFFF9500)
                                : const Color(0xFF253325),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAlarmOn
                                    ? Icons.alarm_on_rounded
                                    : Icons.alarm_off_rounded,
                                size: 14,
                                color: isAlarmOn
                                    ? Colors.white
                                    : const Color(0xFFB0BEB0),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isAlarmOn ? 'Alarm: $wake' : 'Alarm Off',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isAlarmOn
                                      ? Colors.white
                                      : const Color(0xFFB0BEB0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Text and quick stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rest & Recovery',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Target: $durationStr ($bed → $wake)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFB0BEB0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: AppPalette.limeGreen.withValues(alpha: 0.15),
                              foregroundColor: AppPalette.limeGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              AlarmTestDialog.show(
                                context,
                                alarmTime: wake,
                                alarmSound: settings?.alarmSound ?? 'Gentle Chime',
                                vibrate: settings?.vibrate ?? true,
                                snoozeMinutes: settings?.snoozeMinutes ?? 10,
                              );
                            },
                            icon: const Icon(Icons.volume_up_rounded, size: 16),
                            label: const Text(
                              'Test Alarm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
