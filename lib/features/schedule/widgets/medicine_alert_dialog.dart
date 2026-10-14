import 'package:fitbuddy/core/services/app_sound_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app dialog that plays [AppSounds.medicineWarning] and confirms
/// the user has taken their medicine.
class MedicineAlertDialog extends StatefulWidget {
  const MedicineAlertDialog({
    super.key,
    required this.medicineName,
    required this.time,
    this.onTaken,
    this.onSnooze,
  });

  final String medicineName;
  final String time;
  final VoidCallback? onTaken;
  final VoidCallback? onSnooze;

  /// Shows the dialog and plays the medicine warning sound.
  static Future<void> show(
    BuildContext context, {
    required String medicineName,
    required String time,
    VoidCallback? onTaken,
    VoidCallback? onSnooze,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MedicineAlertDialog(
        medicineName: medicineName,
        time: time,
        onTaken: onTaken,
        onSnooze: onSnooze,
      ),
    );
  }

  @override
  State<MedicineAlertDialog> createState() => _MedicineAlertDialogState();
}

class _MedicineAlertDialogState extends State<MedicineAlertDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _triggerHaptics();
    AppSoundService.instance.playMedicineAlert();
  }

  Future<void> _triggerHaptics() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) await HapticFeedback.mediumImpact();
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E281E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: const Color(0xFFE5A000).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE5A000).withValues(alpha: 0.18),
                    border: Border.all(
                      color: const Color(0xFFE5A000),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    size: 40,
                    color: Color(0xFFE5A000),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Medicine Reminder',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'It is ${widget.time}. Time to take your medication:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF283628)
                      : const Color(0xFFF2F7F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF384E38)
                        : const Color(0xFFD8E4D5),
                  ),
                ),
                child: Text(
                  widget.medicineName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        widget.onSnooze?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Snooze 10m'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        widget.onTaken?.call();
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "I've Taken It",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
