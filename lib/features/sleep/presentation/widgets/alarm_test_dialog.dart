import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:fitbuddy/core/services/notification_service.dart';
import 'package:fitbuddy/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive modal dialog that simulates the alarm firing.
class AlarmTestDialog extends StatefulWidget {
  const AlarmTestDialog({
    super.key,
    required this.alarmTime,
    required this.alarmSound,
    required this.vibrate,
    required this.snoozeMinutes,
  });

  final String alarmTime;
  final String alarmSound;
  final bool vibrate;
  final int snoozeMinutes;

  static Future<void> show(
    BuildContext context, {
    required String alarmTime,
    required String alarmSound,
    required bool vibrate,
    required int snoozeMinutes,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlarmTestDialog(
        alarmTime: alarmTime,
        alarmSound: alarmSound,
        vibrate: vibrate,
        snoozeMinutes: snoozeMinutes,
      ),
    );
  }

  @override
  State<AlarmTestDialog> createState() => _AlarmTestDialogState();
}

class _AlarmTestDialogState extends State<AlarmTestDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _triggerHaptics();
    AppSoundService.instance.playWakeUpAlarm();

    // Fire native test notification as well so the user verifies system delivery
    NotificationService.instance.showImmediateNotification(
      id: 9991,
      title: '⏰ Wake-Up Alarm Test',
      body: 'Good morning! It is ${widget.alarmTime}. Time to rise and shine!',
      channelId: 'vyayama_alarm',
      channelName: 'Wake Alarms',
      alarmStyle: true,
    );
  }

  Future<void> _triggerHaptics() async {
    if (!widget.vibrate) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  @override
  void dispose() {
    AppSoundService.instance.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF141A14),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppPalette.limeGreen.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: const Color(0xFFFF9500).withValues(alpha: 0.25),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing Alarm Icon
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFF9500), Color(0xFFE25822)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF9500).withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.alarm_on_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Good Morning! ☀️',
              style: text.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.alarmTime,
              style: text.displaySmall?.copyWith(
                color: AppPalette.limeGreen,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Alarm Sound: ${widget.alarmSound}${widget.vibrate ? ' · Vibrate On' : ''}',
              style: text.bodyMedium?.copyWith(
                color: const Color(0xFFB0BEB0),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: AppSoundService.instance.isPlayingNotifier,
              builder: (context, playing, _) {
                return OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: playing
                        ? AppPalette.limeGreen
                        : const Color(0xFFFF9500),
                    side: BorderSide(
                      color: playing
                          ? AppPalette.limeGreen.withValues(alpha: 0.5)
                          : const Color(0xFFFF9500).withValues(alpha: 0.5),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    if (playing) {
                      AppSoundService.instance.stop();
                    } else {
                      AppSoundService.instance.playWakeUpAlarm();
                    }
                  },
                  icon: Icon(
                    playing
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    size: 18,
                  ),
                  label: Text(
                    playing
                        ? 'Alarm Ringing (Tap to Silence)'
                        : 'Alarm Silenced (Tap to Play)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF9500),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () async {
                await NotificationService.instance.scheduleTestAlarmInSeconds(
                  id: 9992,
                  seconds: 5,
                  title: '⏰ Wake-Up Alarm (5s Test)',
                  body: 'Time to wake up! Have a great day!',
                  channelId: 'vyayama_alarm',
                  channelName: 'Wake Alarms',
                  alarmStyle: true,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Alarm scheduled for 5s from now! Lock your screen to test ⏰',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.timer_outlined, size: 16),
              label: const Text(
                'Schedule 5s Test Alarm (Lock screen to test)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB0BEB0),
                      side: const BorderSide(color: Color(0xFF3B4D3B)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      AppSoundService.instance.stop();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Snoozed for ${widget.snoozeMinutes} minutes 😴',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text('Snooze (${widget.snoozeMinutes}m)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.limeGreen,
                      foregroundColor: const Color(0xFF142014),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      AppSoundService.instance.stop();
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Awesome! Good morning! Have a great day! ⚡'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text(
                      'I\'m Awake!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
