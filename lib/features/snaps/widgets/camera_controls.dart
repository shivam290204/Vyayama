import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Close button and flash toggle shown over the camera preview.
class CameraTopBar extends StatelessWidget {
  const CameraTopBar({
    super.key,
    required this.flash,
    required this.onFlash,
    required this.onClose,
  });

  final FlashMode flash;
  final VoidCallback onFlash;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final icon = switch (flash) {
      FlashMode.off => Icons.flash_off,
      FlashMode.auto => Icons.flash_auto,
      _ => Icons.flash_on,
    };
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            tooltip: 'Close camera',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
          IconButton.filledTonal(
            tooltip: 'Flash: ${flash.name}',
            icon: Icon(icon),
            onPressed: onFlash,
          ),
        ],
      ),
    );
  }
}

/// Timer toggle, capture button and flip button.
class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.timerSeconds,
    required this.enabled,
    required this.onTimer,
    required this.onCapture,
    required this.onFlip,
  });

  final int timerSeconds;
  final bool enabled;
  final VoidCallback onTimer;
  final VoidCallback onCapture;
  final VoidCallback onFlip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final timerIcon = switch (timerSeconds) {
      3 => Icons.timer_3,
      10 => Icons.timer_10,
      _ => Icons.timer_off,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            tooltip: timerSeconds == 0 ? 'Timer off' : 'Timer $timerSeconds seconds',
            icon: Icon(timerIcon),
            onPressed: enabled ? onTimer : null,
          ),
          Semantics(
            button: true,
            enabled: enabled,
            label: 'Take photo',
            child: GestureDetector(
              onTap: enabled ? onCapture : null,
              child: Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 4),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? scheme.primary : scheme.outline,
                  ),
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.flip_camera_android),
            onPressed: enabled ? onFlip : null,
          ),
        ],
      ),
    );
  }
}
