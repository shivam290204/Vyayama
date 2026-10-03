import 'package:flutter/material.dart';

/// Previous, pause/resume and next buttons for the guided session.
class SessionControls extends StatelessWidget {
  const SessionControls({
    super.key,
    required this.paused,
    required this.onPrevious,
    required this.onTogglePause,
    required this.onNext,
  });

  final bool paused;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onPrevious,
            tooltip: 'Previous exercise',
            icon: const Icon(Icons.skip_previous_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onTogglePause,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(paused ? 'Resume' : 'Pause'),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: onNext,
            tooltip: 'Next exercise',
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}
